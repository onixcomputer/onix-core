## 1. Nix Package

- [x] 1.1 Create `pkgs/llamacpp-rocm-rpc/default.nix` — Nix derivation that builds llama.cpp from a pinned git revision with `-DGGML_HIP=ON -DAMDGPU_TARGETS="gfx1151" -DGGML_RPC=ON -DGGML_HIP_ROCWMMA_FATTN=ON`. Output must include `bin/llama-server` and `bin/rpc-server`.
- [x] 1.2 Add the package as a Nix overlay in `flake.nix` (or an overlays file) so it's available as `pkgs.llamacpp-rocm-rpc` in all NixOS configurations.
- [x] 1.3 Verify the package builds: `nix build .#packages.x86_64-linux.llamacpp-rocm-rpc` produces both binaries.

## 2. Clan Service Module

- [x] 2.1 Create `modules/llamacpp-rpc/default.nix` with the clan perInstance pattern, defining two roles: `worker` and `server`.
- [x] 2.2 Implement the `worker` role — options for `bindAddress`, `port`, `enableCache`. The perInstance nixosModule creates a `llamacpp-rpc-worker.service` systemd unit running `rpc-server` with the correct flags, opens the firewall port.
- [x] 2.3 Implement the `server` role — options for `host`, `port`, `modelPath`, `rpcWorkers`, `gpuLayers`, `flashAttention`, `contextSize`, `noMmap`, `extraArgs`. The perInstance nixosModule creates a `llamacpp-inference.service` systemd unit running `llama-server`, opens the API port, creates `/var/lib/llamacpp/models/`, orders after `network-online.target`.
- [x] 2.4 Register the module in `modules/default.nix` as `"llamacpp-rpc"`.

## 3. Inventory and Tags

- [x] 3.1 Add `llamacpp-worker` and `llamacpp-server` tags to `inventory/core/contracts.ncl` tag registry.
- [x] 3.2 Add a service instance in `inventory/services/services.ncl` for `llamacpp-rpc` with `worker` role tagged `llamacpp-worker` and `server` role tagged `llamacpp-server`. Configure the server role's `rpcWorkers` to `["10.10.10.2:50052"]` and `modelPath` to a sensible default.
- [x] 3.3 Add the `llamacpp-worker` tag to aspen2 and `llamacpp-server` tag to aspen1 in `inventory/core/machines.ncl`.

## 4. Build Verification

- [x] 4.1 Run `build aspen1` — verify it succeeds and includes `llamacpp-inference.service`.
- [x] 4.2 Run `build aspen2` — verify it succeeds and includes `llamacpp-rpc-worker.service`.

## 5. Deployment and Smoke Test

- [x] 5.1 Deploy to aspen2 first (`clan machines update aspen2`), verify `rpc-server` is running and listening on `10.10.10.2:50052`.
- [x] 5.2 Deploy to aspen1 (`clan machines update aspen1`), verify `llama-server` starts and connects to the RPC worker.
- [x] 5.3 Download a test model (e.g., Qwen 3.5 122B Q8_0 GGUF) to `/var/lib/llamacpp/models/` on aspen1.
- [x] 5.4 Restart the inference service, confirm the model loads and distributes layers across both GPUs.
- [x] 5.5 Send a test request to `http://aspen1:8081/v1/chat/completions` and verify a response is returned.
