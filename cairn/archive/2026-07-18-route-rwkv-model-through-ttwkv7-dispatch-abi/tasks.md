# Tasks

## Lifecycle

- [x] [serial] Frame the physical-seeded real-model dispatch goal, state ownership, BF16 boundaries, controls, and non-claims r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Expose the pure canonical dispatch step and ordered transcript core without adding process or device access r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Reconstruct the exact observed second-token model state and route twelve third-token WKV calls through framed CPU dispatch r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Add independent BF16 oracle, all-layer reset/transpose controls, untied-head ranking, and complete-vector receipts r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Package fixed evidence invocation, deterministic replay, mutation, ordering, source-surface, and closure checks r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Rebuild historical dispatch/model/state/layer and boundary checks in a clean detached worktree r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
- [x] [serial] Sync, archive, commit both boundaries, and preserve the hardware-authorization blocker r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_model_dispatch]
