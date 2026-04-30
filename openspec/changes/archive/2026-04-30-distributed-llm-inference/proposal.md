## Why

aspen1 and aspen2 are connected via a 40 Gbps USB4/Thunderbolt link with static IPs (10.10.10.1/2). Each machine has ~124 GB of GPU-accessible GTT memory (Strix Halo, gfx1151, ROCm). Running Qwen 3.5 122B at Q4 on a single node works, but higher quantizations (Q8) and larger models require splitting across both machines. llama.cpp RPC is the proven approach for this hardware (per AMD's own clustering guide and Jeff Geerling's testing on identical Framework Desktops).

## What Changes

- Add a new `llamacpp-rpc` clan service module that manages the llama.cpp RPC server daemon on worker nodes and the llama-server instance on the main node
- Build llama.cpp from source with ROCm HIP, flash attention (`-DGGML_HIP_ROCWMMA_FATTN=ON`), and RPC support (`-DGGML_RPC=ON`) targeting gfx1151
- Configure aspen2 as an RPC worker exposing its GPU over `10.10.10.2:50052`
- Configure aspen1 as the main node running `llama-server` with `--rpc 10.10.10.2:50052` and an OpenAI-compatible API
- Add a model management mechanism to download GGUF models to a shared or mirrored path
- Wire firewall rules so port 50052 is open on the thunderbolt interface (already trusted, but the RPC port should also be available on the regular network for flexibility)

## Capabilities

### New Capabilities
- `llamacpp-rpc-server`: Systemd service for llama.cpp RPC worker nodes — builds llama.cpp with ROCm/RPC, runs rpc-server bound to a configurable address/port, exposes GPU to the cluster
- `llamacpp-inference`: Systemd service for the main inference node — runs llama-server with RPC backends, configurable model path, GPU layers, flash attention, and OpenAI-compatible API endpoint
- `llamacpp-package`: Nix package for llama.cpp built from source with ROCm HIP (gfx1151), RPC, and flash attention support

### Modified Capabilities

## Impact

- `machines/aspen1/configuration.nix` — may add inference server config or service instance references
- `machines/aspen2/configuration.nix` — may add RPC worker config
- `modules/` — new `llamacpp-rpc` module directory
- `inventory/services/` — new service instance wiring aspen1 as main, aspen2 as worker
- `inventory/core/machines.ncl` and `inventory/core/contracts.ncl` — new tags if using tag-based deployment
- Existing Ollama service on aspen1 (port 11434) is unaffected — llama-server uses a different port (8080)
