## Phase 1: Lifecycle and baseline

- [x] [serial] Establish the focused package and accelerator-inventory baseline before changing core package behavior. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
- [x] [serial] Validate the proposal, design, tasks, and delta requirements before implementation. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]

## Phase 2: Implementation

- [x] [serial] Preserve Blackhole and Wormhole SFPU finalization semantics in both chunked and decode constant generators. r[onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu]
- [x] [serial] Add the pure exact constant-tile oracle, positive and negative self-tests, and bounded probe shell. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
- [x] [serial] Add minimal device compute/writer kernels that emit every chunked mask for the two reviewed boundary lengths in one device open. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]

## Phase 3: Offline validation and deployment

- [x] [serial] Run package checks, probe self-tests, and offline Blackhole and Wormhole JIT compilation for the affected kernels. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
- [x] [serial] Build the accelerator inventory and complete britton-desktop closure, then commit the exact reviewed revision. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
- [ ] [serial] Deploy the reviewed commit from an isolated clean source tree without changing SSH/SOPS rotation material. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]

## Phase 4: One bounded hardware probe

- [ ] [serial] Stop the device-1 owner, invoke the constant-tile probe exactly once, restore the owner through a trap, and collect service and board-health evidence without retry. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
- [ ] [serial] Record the exact measured boundary, sync accepted requirements, and archive the completed or bounded-blocked change. r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe]
