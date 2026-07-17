## Why

The accepted real-weight boundary fixture proves exact logical BF16 bytes and CPU recurrence expectations, while the repaired ttWKV7 host proves that a synthetic 12-head shape can be padded and tilized. No accepted artifact currently proves that the real checkpoint bytes survive the production host's input padding, state upload, tiled-NFACES conversion, or writer output/state packing. The next device-free rung should close that host-layout gap before any separately authorized hardware process.

## What Changes

- Extract the production host's checkpoint input padding, state upload, and writer output/state index calculations into a shared pure C++ header used by the runner and the no-device data-movement validator.
- Add a strict `boundary-self-test` mode that accepts only the exact package-owned real-weight fixture, validates complete metadata, BF16 bytes, and BLAKE3 identities, and proves Metalium's CPU layout conversion matches an independent tiled-NFACES oracle.
- Add a cross-package Nix check that binds the pinned fixture to deterministic transformed-buffer receipts and rejects malformed, reordered, changed, transposed, truncated, duplicated, or suffixed inputs.
- Keep all device creation behind existing hardware-only modes and preserve historical diagnostics and architecture checks.

## Impact

- **Files**: `pkgs/ttwkv7/ttwkv7-host-layout.h`, `pkgs/ttwkv7/data-movement-probe.cpp`, ttWKV7 build/runtime checks, `flake-outputs/ttwkv7.nix`, and this Cairn change package
- **Testing**: baseline and final ttWKV7 packages, cross-package host-layout check, dual-architecture kernels, deterministic replay, positive and negative fixture mutations, focused formatting/linting, and clean Cairn validation/gates
