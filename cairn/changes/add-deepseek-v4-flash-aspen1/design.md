# Design: add-deepseek-v4-flash-aspen1

## Reference deployment

Source: github.com/darnoq99/deepseek-v4-flash-0731-strix-halo (verified on Ryzen AI Max+ 395, Radeon 8060S `gfx1151`, 128 GiB UMA, ROCm 6.4). Result: 21.31 tok/s decode at 8192 context, 67.46% speculative acceptance, ~114 GiB resident, no OOM.

Verified configuration:

- Main model: `unsloth/DeepSeek-V4-Flash-0731-GGUF`, `UD-IQ3_XXS`, 4 shards (~104 GB). SHA-256 values in the guide match the current HF LFS objects.
- Drafter: `alessandrobologna/DeepSeek-V4-Flash-0731-DSpark-Drafter-GGUF`, file `DeepSeek-V4-Flash-0731-DSpark-Drafter-MXFP4-Q8_0.gguf` (~10.9 GB).
- llama.cpp commit `0b14b87d7c20cb753b94b96854dd7b45306fc696`, HIP `gfx1151`, flags `GGML_HIP_MMQ_MFMA=ON GGML_HIP_NO_VMM=ON GGML_HIP_GRAPHS=OFF GGML_NATIVE=OFF`.
- Launch: `-m <shard1> -md <drafter> --spec-type draft-dspark --spec-draft-n-max 3 -ngl all -ngld all --fit off -c 8192 -np 1 -fa on -ctk q8_0 -ctv q8_0 -ctkd q8_0 -ctvd q8_0 --load-mode dio`.

## Decisions

**Pin the known-good commit, not a release tag.** The guide names the exact commit as known-good for the 0731 architecture and `draft-dspark` speculation. The existing `llamacpp-rocm-rpc` package (b9859) stays untouched because Lemonade on aspen2/aspen3 depends on it. A separate `llamacpp-rocm-dspark` package carries the pin.

**Direct llamacpp-server, not Lemonade.** Lemonade custom models accept only checkpoint, recipe, and size. There is no surface for a draft model or `--spec-type draft-dspark`. The existing `llamacpp-server` clan module already downloads models and runs `llama-server` with managed flags; it needs three extensions:

1. `extraModelFiles`: additional files pulled from `modelRepo` (shards 2-4). The pull script creates parent directories because shard paths contain the `UD-IQ3_XXS/` prefix.
2. `draftModelRepo` / `draftModelFile` / `draftModelRevision`: optional draft model pull. When set, the module adds `--model-draft <path>`.
3. Backend enum value `rocm-dspark` selecting `pkgs.llamacpp-rocm-dspark`.

All speculative and KV flags go through the existing `extraArgs` escape hatch so the module stays generic.

**Keep port 13305.** Every mesh-llm node targets `http://127.0.0.1:13305/v1`. Binding the new server to 13305 means only the aspen1 `backendUnit` changes; joiners keep working against their local Lemonade.

**Remove `lemonade-aspen1` entirely.** The 0731 server needs ~120 GiB free at startup and ~114 GiB resident. Lemonade with `globalTimeout = 0` keeps models resident and would OOM the 0731 server. The operator accepted losing kokoro-v1 and aspen1 Ornith endpoints. Disabling also removes the Lemonade cluster-RPC client on aspen1; the aspen2/aspen3 workers then serve standalone, which matches their configuration.

**Memory budget.** Weights ~97 GiB + drafter ~10.2 GiB + q8_0 KV at 8K context ~2 GiB fits the 124 GiB GTT aperture already set by the `rdma-cluster` tag (`amdgpu.gttsize=126976`, `ttm.pages_limit=32505856`). The guide's `--kv-unified` remark is omitted: the verified `start.sh` does not use it, and on Strix Halo GTT is unified memory.

**Context and experts stay at model defaults.** 8192 context as verified; no expert top-k override (that was a Lucebox flag and does not apply to llama.cpp).

## Risks

- `npmDepsHash` for the pinned commit differs from b9859; discovered by a failing build and recorded.
- First startup downloads ~115 GB through the pull service; `TimeoutStartSec` is already infinite and curl resumes.
- The alessandrobologna drafter SHA-256 differs from the guide's locally converted drafter; the guide states both are compatible. Live speculative-acceptance telemetry is the acceptance signal.
- If HIP build flags from nixpkgs conflict with the guide flags, the nixpkgs `llama-cpp` override surface (`rocmSupport`, `rocmGpuTargets`) plus explicit `cmakeFlags` wins by construction order.

## Rollback

Repoint the aspen1 mesh-llm `backendUnit` to `lemonade.service` and restore the `lemonade-aspen1` inventory block from git history. The Ornith and kokoro models are unchanged in inventory history.
