## Why

Run the publicly released Nemotron 3.5 Super VL on the existing DGX Sparks for verifier-assisted Rust proof development. Reasonable's article reports an unreleased Verus fine-tune, training corpus and evaluation harness; serving NVIDIA's public model cannot reproduce its 73.3% result.

## What Changes

- Provide a digest/revision-pinned, standalone NVFP4 lifecycle launcher for one stock-Ubuntu GB10 Spark, bound only to loopback.
- Reuse the sibling Trellis checkout's existing proofs and production Verus package in an isolated OpenCode proof/repair session through an SSH tunnel.
- Exercise real reasoning, tool calls and solver-checked proof completion. Preserve the theorem and reject additions of trust escapes rather than accepting an unverified model answer.
- Perform only the user-approved temporary GPU cutover; restore the existing three-rank DeepSeek deployment afterward.

## Impact

- **Files**: `scripts/nemotron-spark.sh`, `scripts/nemotron-verus.sh` and its required support files, usage documentation, and this native Cairn change.
- **Testing**: actual Spark container/model startup, model API and agent tool loop, unsolved-before/verified-after Trellis proof, and restored DeepSeek inference.
- **Non-goals**: no OS reinstall, Clan/Devenv machine enrollment, global GPU changes, Trellis source edits, invented Reasonable assets, LoRA training claim, or benchmark-score claim.
