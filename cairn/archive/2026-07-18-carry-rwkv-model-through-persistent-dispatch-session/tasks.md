# Tasks: Carry RWKV through one persistent dispatch session

- [x] [serial] Add the pure single-pending dispatch-session lifecycle with exact ordering, per-layer BF16 continuity, fault, and close invariants r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Add positive and negative lifecycle tests covering completion, continuity, malformed authority, timeout, interruption, duplicate response, and premature close r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Route third and greedily selected fourth-token all-layer WKV calls through one session and compare against the independent BF16 oracle r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Preserve reset/transposed controls, exact physical seed authority, prior receipts, and zero-new-physical-call accounting r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Add the fixed-invocation binary, deterministic receipt, Nix check, mutation checks, closure isolation, and source-surface rejection r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Rebuild focused and historical checks in a clean detached worktree and record the clippy result r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
- [x] [serial] Sync, archive, and commit implementation and lifecycle boundaries without running hardware r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_model_dispatch]
