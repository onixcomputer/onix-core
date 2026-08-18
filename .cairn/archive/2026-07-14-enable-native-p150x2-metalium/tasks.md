## Phase 1: Native runtime integration

- [x] [serial] Select and install native `tt-metal` plus `llama-cpp-metalium` from the pinned input. r[onix.tenstorrent.native_runtime.packages]
- [x] [serial] Export the Metalium roots and shipped `p150_x2` mesh descriptor path. r[onix.tenstorrent.native_runtime.p150x2_mesh]
- [x] [serial] Add a native runtime layout check covering the expected descriptor and a missing-descriptor negative case. r[onix.tenstorrent.native_runtime.p150x2_mesh]
- [x] [serial] Update generated host documentation with firmware and P150x2/P300 boundaries. r[onix.tenstorrent.native_runtime.firmware_boundary] r[onix.tenstorrent.native_runtime.identity]

## Phase 2: Verification and lifecycle

- [x] [serial] Run Nix formatting, pre-commit, `britton-desktop` evaluation, and native package validation. r[onix.tenstorrent.native_runtime.packages] r[onix.tenstorrent.native_runtime.p150x2_mesh]
- [x] [serial] Validate Cairn gates and record the exact runtime blocker if hardware execution requires a manual firmware update. r[onix.tenstorrent.native_runtime.firmware_boundary]
