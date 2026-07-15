## Why

`britton-desktop` has two Blackhole p150a cards connected through two QSFP-DD cables, while the current `tenstorrent` tag stops at driver, hugepage, firmware-tooling, and diagnostic setup. The pinned `tenstorrent.nix` input already provides native `tt-metal`, TT-NN bindings, `llama-cpp-metalium`, and the upstream `p150_x2` mesh descriptor, so the host should expose that supported native runtime instead of requiring mutable installer state or misidentifying the pair as a P300.

## What Changes

- Add the pinned native `tt-metal` and `llama-cpp-metalium` packages to Tenstorrent hosts.
- Export `TT_METAL_HOME`, `TT_METAL_RUNTIME_ROOT`, and the upstream `p150_x2` mesh descriptor path system-wide.
- Document the P150x2 topology, native-runtime verification, and the distinction between P150x2 and the unsupported TT-Inference-Server `p300` shortcut.
- Keep firmware flashing manual and operator-reviewed.

## Impact

- **Files**: `inventory/tags/tenstorrent.nix`, native Cairn lifecycle artifacts under `cairn/changes/enable-native-p150x2-metalium/`
- **Testing**: Cairn validation and stage gates, Nix formatting, pre-commit checks, `britton-desktop` NixOS evaluation, and native package dry-run/build validation
