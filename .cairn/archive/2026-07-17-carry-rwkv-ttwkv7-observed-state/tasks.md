## 1. Lock the recurrent carry boundary

- [x] [serial] Record the accepted observed-layer receipt identity, third token ID, host-state ownership, matrix-state ownership, BF16 transport points, reset controls, and narrow non-claims r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Add the delta requirement and pass proposal/design/tasks gates before implementation r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]

## 2. Implement the functional core

- [x] [serial] Expose deterministic final attention/channel host state from the existing two-token CPU sequence without changing any accepted receipt r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Add pure next-token continuation for source FP32 and BF16-boundary paths using explicit host and matrix state r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Add complete-vector receipt construction for source, expected, observed, reset, and transposed controls with named divergence floors r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]

## 3. Package and reject drift

- [x] [serial] Add a fixed `--evidence-root PATH` state-carry binary and separate Nix check r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Add repeated-determinism, malformed evidence, unexpected-argument, prior-receipt, reset/transposed-state discrimination, and closure-isolation checks r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Rebuild the accepted historical checks and refresh only mechanically dependent boundary-plan hashes if required r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]

## 4. Validate and close

- [x] [serial] Run focused formatting, clean detached-worktree builds, Cairn validation, and proposal/design/tasks gates; record exact receipts, deviations, identities, and blockers r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
- [x] [serial] Sync the accepted requirement, archive the completed change, commit both boundaries, and report the exact CPU-continuation claim and remaining hardware authorization blocker r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_state_carry]
