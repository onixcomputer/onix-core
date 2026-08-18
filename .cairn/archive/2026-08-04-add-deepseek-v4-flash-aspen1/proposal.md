# Proposal: add-deepseek-v4-flash-aspen1

## Why

aspen1 (Ryzen AI Max 300, Radeon 8060S `gfx1151`, 128 GiB unified memory) can run the final DeepSeek-V4-Flash-0731 release locally. A verified community deployment (darnoq99/deepseek-v4-flash-0731-strix-halo) reaches 21.31 tok/s decode with DSpark speculative decoding on identical hardware, fully resident in unified memory. The operator wants this model as the aspen1 mesh-llm backend and accepts stopping the current Lemonade models (Ornith 9B/35B, kokoro-v1) to free the required ~114 GiB.

The Lucebox path from the earlier blog post is rejected: its ROCMFPX target is the preview release, not 0731, and the verified guide measured only 6-12 tok/s with a draft-format mismatch. Lemonade cannot express DSpark speculative decoding (`--spec-type draft-dspark` plus a draft model), so the direct `llamacpp-server` module is the serving path.

## What Changes

- Add `pkgs/llamacpp-rocm-dspark`: llama.cpp pinned to the known-good commit `0b14b87d7c20cb753b94b96854dd7b45306fc696`, HIP `gfx1151`, with the guide's cmake flags.
- Extend `modules/llamacpp-server` with multi-file model pulls (GGUF shards in subdirectories), an optional DSpark draft model, and a `rocm-dspark` backend selector.
- Add inventory service `deepseek-v4-flash-aspen1`: unsloth `UD-IQ3_XXS` (4 shards, ~104 GB) plus the MXFP4-Q8_0 DSpark drafter (~10.9 GB), port 13305, context 8192, q8_0 KV cache.
- Repoint the aspen1 mesh-llm seed `backendUnit` at the new service. The endpoint URL stays `http://127.0.0.1:13305/v1`.
- Remove the `lemonade-aspen1` inventory service so Lemonade cannot load models and OOM the 0731 server. aspen2/aspen3 Lemonade is unchanged.

## Impact

- **Files**: `pkgs/llamacpp-rocm-dspark/default.nix`, `flake-outputs/tools.nix`, `inventory/tags/common/shared-nix.nix`, `modules/llamacpp-server/default.nix`, `modules/llamacpp-server/schema.ncl`, `inventory/services/services.ncl`
- **Testing**: `cairn validate` and gates, package build, `nixosConfigurations.aspen1` evaluation, live deployment probe (health, chat completion, speculative acceptance), negative check that Lemonade no longer starts on aspen1
- **Operator impact**: kokoro-v1 TTS and aspen1-hosted Ornith endpoints go away (accepted). The Lemonade cluster-RPC client on aspen1 also stops; aspen2/aspen3 keep serving their own models.
