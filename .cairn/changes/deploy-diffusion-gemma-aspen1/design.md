## Context

This record covers the initial isolated deployment. The subsequent [mesh integration](../expose-diffusion-gemma-mesh-llm/design.md) updates its exposure without restarting the model.

Both Aspen candidates use Radeon 8060S/gfx1151 rather than NVIDIA. Aspen1 exposes 96 GiB of GPU-accessible shared memory. Its Qwen service was enabled but inactive; the mesh sidecar could request that backend through a Wants dependency. The three Sparks are occupied by a tensor-parallel DeepSeek deployment and are outside this change.

## Decisions

### Decision: Use the original model on Aspen1

**Choice:** Pin google/diffusiongemma-26B-A4B-it at f7f5b7f5fa82ffc52addd066915886d497f5517b and run it with native ROCm, not NVIDIA NVFP4.

**Rationale:** The original BF16 weights fit Aspen1 with headroom. Qualified gfx1151 runtime artifacts and independent same-model inference results provided the starting point; local inference now verifies the deployed model.

### Decision: Match structured-read source and native runtime

**Choice:** Build vLLM PR 57250 at 58eacf242207c9b9b54abff57e684fc1a7d74548 against the qualified ROCm runtime. Do not overlay September Python files onto the July binary bundle. Launch through the source build's supported `python3 -m vllm.entrypoints.cli.main` interface.

**Rationale:** Sampling, scheduling, model-state and weight-loading interfaces changed between those versions. A successful import alone is not inference evidence. SDK restoration initially left unrecorded flattened library aliases that loaded LLVM twice; removing those aliases resolves the reproduced `spirv-expand-step` registration failure. The repaired image passes native BF16 execution and real model requests.

### Decision: Admit one model without a whole-host switch

**Choice:** Use a dedicated /var/lib/diffusion-gemma state tree and a separate loopback API. Persistently mask only the stopped Aspen1 Qwen server while DiffusionGemma owns the GPU, and express that state in the Aspen1 Nix module. Leave Qwen model files, Aspen2 and mesh routes unchanged. Copy and root only the required service closure on the target.

**Rationale:** Whole-host activation would apply unrelated current repository changes. A mask prevents the mesh Wants dependency from restarting the displaced backend.

## Risks / Trade-offs

- AMD structured-read support is experimental; actual text and seeded-canvas responses passed on this pinned image, not arbitrary ROCm/vLLM versions.
- Unified memory is shared with host services. Context is bounded to 4096 tokens, concurrency to one sequence and KV allocation to 2 GiB. Backend/frontend container limits are 88/4 GiB, but Docker limits do not account for every possible driver allocation.
- Consumer RDNA latency must be measured locally, not inferred from the Spark benchmark. Recorded timings are individual smoke requests, not a throughput or tail-latency benchmark.
- Direct APIs remain loopback-only. Following mesh integration, chat and native seeded-canvas requests are available through the existing private mesh; the structured frontend remains reachable through SSH forwarding.
- Conventional sampling parameters such as `temperature` and `seed` are unsupported by the diffusion backend and must be omitted. The structured API's seed controls canvas initialization instead.

## Operating State

- Mesh access after the follow-up integration: use model `diffusiongemma` at `http://127.0.0.1:9337/v1` on the existing desktop mesh peer. No separate Aspen tunnel is needed for those requests.
- Backend: `docker-diffusion-gemma.service`, OpenAI-compatible chat requests at `http://127.0.0.1:8000/v1/chat/completions`, model name `diffusiongemma`.
- Structured frontend: `docker-diffusion-gemma-structured.service`, verified through `http://127.0.0.1:8001/v1/systemone`.
- Restart with `systemctl restart docker-diffusion-gemma.service`; the frontend follows through `PartOf`, and the backend wants it on startup.
- The selected unit closure is GC-rooted at `/nix/var/nix/profiles/diffusion-gemma`. Persistent unit attachments and multi-user wants live under `/etc/systemd/system.attached`; the Qwen mask lives under `/etc/systemd/system.control`.
- Model state and the pinned image archive remain under `/var/lib/diffusion-gemma`. `machines/aspen1/diffusion-gemma/runtime.json` records the model/source revisions, image ID and archive SHA-256.
- On `britton-desktop`, forward the APIs with `ssh -N -L 18000:127.0.0.1:8000 -L 18001:127.0.0.1:8001 root@aspen1.local`, then use local ports 18000 and 18001. This uses the desktop's existing Aspen credentials rather than assuming a client has the same keys.
- Restoring Qwen requires first stopping both DiffusionGemma services and explicitly changing the persistent ownership configuration and mask. Do not start both GPU owners concurrently.

## Measured Verification

- `model-probe.json`: original checkpoint integrity, architecture and tensor counts.
- `runtime-probe.json`, `native-runtime-probe.json`: qualified native runtime and repaired source-build execution.
- `sdk-alias-reproduction.json`: reproduced LLVM packaging failure and the repair.
- `service-baseline.json`: pre-deployment service identities and persistent installation boundaries.
- `inference.json`: real text generation and state-sensitive red/blue structured decisions.
- `verification.json`: a successful post-restart structured decision, direct seeded read-only canvas request with finite returned label log probabilities, loopback listeners, persistent boot wants and unchanged mesh/music/Docker invocation identities.
- After restart and inference, GTT use was 57,049,378,816 bytes (about 53.13 GiB), with 63,577,620,480 bytes (about 59.21 GiB) of host memory available. Qwen remained masked and inactive.
