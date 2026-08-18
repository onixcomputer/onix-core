## 1. Lock the all-layer boundary

- [x] [serial] Record the accepted physical boundary, prior receipt identities, all-layer state ownership, token positions, BF16 transport points, and non-claims r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Add the delta requirement and pass proposal/design/tasks gates before core implementation r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]

## 2. Refactor the functional core

- [x] [serial] Add an explicit pure layer-zero WKV mode while preserving ordinary full-model receipt bytes r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Retain ordered per-layer token outputs and complete attention/channel/matrix state without changing historical output schemas r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]

## 3. Compose and audit model paths

- [x] [serial] Build source, expected, observed, reset, and transposed three-token all-layer paths from immutable evidence r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Apply final normalization and the untied LM head with independent top-two audit and complete-vector receipts r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Require observed/expected proximity plus reset/transposed complete-state and logit divergence r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]

## 4. Package and reject drift

- [x] [serial] Add the fixed `--evidence-root PATH` binary, separate Nix check, deterministic receipt replay, and prior-receipt locks r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Add malformed evidence, invocation, layer-order, reset/orientation, source-surface, and closure negative checks r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]

## 5. Validate and close

- [x] [serial] Rebuild focused and historical checks in a clean detached worktree and record exact receipts, deviations, identities, and blockers r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
- [x] [serial] Sync the accepted requirement, archive the completed change, commit both boundaries, and preserve the hardware authorization blocker r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_observed_model_carry]
