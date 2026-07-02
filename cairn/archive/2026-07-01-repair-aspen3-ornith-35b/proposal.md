## Why

After the 35B Q8 Ornith model finished downloading on `aspen3`, both chat and completion probes returned only slash tokens. The behavior reproduced with llama.cpp CPU-only execution, so it is not a ROCm offload issue. Clients need a working 35B Ornith endpoint instead of a registered model that appears healthy but emits unusable text.

## What Changes

- Advance the local ROCm/RPC llama.cpp package from b9747 to b9859 and preserve the `llama-rpc-server` compatibility alias after upstream renamed the binary to `ggml-rpc-server`.
- Serve `Ornith-1.0-35B-Q4_K_M` on `aspen3` instead of the broken `Ornith-1.0-35B-Q8_0` entry.
- Keep `Ornith-1.0-9B-Q8_0` as the fast fallback model.

## Impact

- **Files**: `pkgs/llamacpp-rocm-rpc/default.nix`, `inventory/services/services.ncl`
- **Testing**: package build, `aspen3` system build/deploy, live positive Q4 response, live negative Q8 slash-loop diagnosis, service inventory export, and Cairn validation/gates.
