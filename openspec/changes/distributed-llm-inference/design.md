## Context

aspen1 and aspen2 are Framework Desktop machines with AMD Ryzen AI Max+ 395 (Strix Halo, gfx1151). Each has ~124 GB GPU-accessible GTT memory via ROCm. They are connected via a 40 Gbps USB4/Thunderbolt link with static IPs (10.10.10.1 for aspen1, 10.10.10.2 for aspen2) and a trusted firewall interface. Both already run Ollama on port 11434.

llama.cpp with RPC is the proven distributed inference approach for this hardware. AMD's own clustering guide and Jeff Geerling's testing on identical hardware validate llama.cpp RPC with ROCm HIP and flash attention on gfx1151. The existing llama.cpp nixpkgs package does not include RPC support or the ROCm flash attention flags needed.

The repo uses clan-core's perInstance module pattern for services, with tag-based deployment via inventory. Existing examples: `modules/ollama/default.nix`, `modules/llm/default.nix`.

## Goals / Non-Goals

**Goals:**
- Build llama.cpp from source with ROCm HIP (gfx1151), flash attention, and RPC support as a Nix package
- Run an RPC worker on aspen2 that exposes its GPU over the thunderbolt link
- Run llama-server on aspen1 that distributes model layers across both GPUs via RPC
- Expose an OpenAI-compatible API endpoint for inference
- Support configuring which GGUF model to load and basic inference parameters
- Coexist with the existing Ollama service

**Non-Goals:**
- Auto-downloading models from HuggingFace (manual download for now — models are large)
- NFS or shared storage for model files (each node keeps a local copy, or the main node streams via RPC)
- Supporting more than 2 nodes (design for 2, but don't prevent scaling)
- Replacing Ollama — this runs alongside it for models that need distributed inference
- vLLM or exo integration (neither works on this hardware today)
- NPU support (not available for gfx1151 in llama.cpp)

## Decisions

### 1. Nix overlay package for llama.cpp with ROCm+RPC

**Decision**: Create a Nix package overlay that builds llama.cpp from source with:
```
-DGGML_HIP=ON
-DAMDGPU_TARGETS="gfx1151"
-DGGML_HIP_ROCWMMA_FATTN=ON
-DGGML_RPC=ON
```

**Rationale**: The nixpkgs `llama-cpp` package doesn't expose RPC or rocWMMA flash attention build flags. Building from source in an overlay gives us control over the exact flags while tracking upstream releases.

**Alternatives considered**: Patching nixpkgs llama-cpp — more fragile, harder to maintain. Using a flake input for llama.cpp — adds input management overhead for something that changes frequently.

### 2. Two clan service roles: `worker` and `server`

**Decision**: Single `llamacpp-rpc` clan service module with two roles:
- `worker` role: runs `rpc-server` on a configurable address/port
- `server` role: runs `llama-server` with `--rpc` pointing to worker addresses

**Rationale**: Follows the existing pattern (e.g., `llm` module has `server` and `client` roles). Workers and servers share the same package but different systemd units. Tag-based deployment means adding a tag deploys the right role.

**Alternatives considered**: Separate modules for worker and server — more files, redundant package definition. Single role with conditional — less clear intent.

### 3. Model storage path

**Decision**: Models stored at `/var/lib/llamacpp/models/` on the main node. The llama.cpp RPC protocol handles streaming model layers to workers — workers don't need a local copy of the model file.

**Rationale**: llama.cpp RPC transfers tensor data over the network during model load. Only the main node needs the GGUF file. This avoids needing to sync 100+ GB model files.

### 4. Port allocation

**Decision**:
- RPC worker: port 50052 (llama.cpp default)
- llama-server API: port 8081 (avoids conflict with port 8080 used by other services)

**Rationale**: Port 50052 is the llama.cpp RPC convention. Port 8081 avoids conflicts with existing services. Both configurable via module options.

### 5. Flash attention enabled by default

**Decision**: Build with `-DGGML_HIP_ROCWMMA_FATTN=ON` and pass `-fa` flag to llama-server by default.

**Rationale**: Testing shows ~140% speedup at long contexts (3.46 → 8.30 t/s at seq_len 8192) on Strix Halo. No downside observed.

### 6. Service inventory wiring

**Decision**: Use tag-based deployment with two new tags:
- `llamacpp-worker`: machines running the RPC worker
- `llamacpp-server`: machines running llama-server

Service instance in `inventory/services/services.ncl` maps tags to roles.

**Rationale**: Follows existing patterns (e.g., `llm` tag → ollama server role). Tags make it declarative which machines serve which role.

## Risks / Trade-offs

- **[RPC is experimental]** → llama.cpp marks RPC as proof-of-concept. It works for 2-node setups but may segfault with very large models. Mitigation: systemd restart-on-failure, start with tested model sizes (Qwen 3.5 122B Q8).

- **[ROCm build fragility]** → ROCm + rocWMMA builds can break across kernel/driver updates. Mitigation: pin llama.cpp version in the package, test builds before deploying.

- **[Network serialization overhead]** → Even at 40 Gbps, distributed inference is slower than single-node. Expect ~25-30% throughput loss. Mitigation: only use for models that don't fit on one node.

- **[Model loading time]** → Large GGUF files (130+ GB) take time to load and distribute over RPC. Mitigation: use `--no-mmap` flag, keep the service running (don't restart frequently).

- **[Single point of failure]** → Main node controls inference. If it crashes, the whole thing stops. Mitigation: systemd auto-restart. Not designed for HA.
