## Phase 1: Reviewed security boundary

- [x] [serial] Establish passing accelerator-inventory and complete host-closure baselines before changing privilege policy. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
- [x] [serial] Validate the proposal, design, tasks, and delta requirement before implementation. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]

## Phase 2: Least-privilege implementation

- [x] [serial] Declare exact passwordless start, stop, and device-ownership commands without wildcard or unrelated root authority. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
- [x] [serial] Install an immutable owner-control wrapper with validate, isolate, restore, and fail-closed invalid-input behavior. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
- [x] [serial] Add positive and negative machine checks for the exact capability, wrapper composition, and rejected broad command shapes. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
- [x] [serial] Document activation and the separation between owner control and hardware authorization. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]

## Phase 3: Offline closure

- [x] [serial] Rebuild the accelerator inventory and complete host closure, then run wrapper, formatting, and Cairn gates without deployment or hardware access. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
- [x] [serial] Sync the accepted requirement, archive the completed change, and commit it from the isolated worktree. r[onix.tenstorrent.native_runtime.ttwkv7.owner_control]
