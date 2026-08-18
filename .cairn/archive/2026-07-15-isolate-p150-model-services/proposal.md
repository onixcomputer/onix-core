## Why

The two Blackhole P150 cards can run independent model servers concurrently, but `GGML_METALIUM_DEVICE_ID` alone does not isolate TT-Metal's UMD discovery. A second process sees both cards and waits on the first process's `CHIP_IN_USE` lock. Official TT-Metal guidance requires `TT_VISIBLE_DEVICES` plus a unique `TT_METAL_CACHE` per process.

A controlled test using that guidance ran VibeThinker on physical card 0 and Supra-Router-51M on physical card 1 at the same time. Both returned HTTP 200 responses with valid model output, establishing a deployable two-service layout.

## What Changes

- Make Metalium `llamacpp-server` instances isolate the configured physical card with `TT_VISIBLE_DEVICES` and select remapped logical device 0.
- Give each Metalium service private cache, log, and inspector-RPC locations.
- Move the existing Supra-Router-51M service from CUDA to Metalium on physical card 1 while VibeThinker remains on physical card 0.
- Preserve the host P150x2 descriptor for mesh-aware workloads while removing it from independent single-card services.

## Impact

- **Files**: `modules/llamacpp-server/default.nix`, `machines/britton-desktop/configuration.nix`, focused validation fixtures, and this Cairn change package
- **Testing**: positive and negative module evaluation, full `britton-desktop` evaluation/build, pre-commit, Cairn gates, concurrent health checks, concurrent model requests, and physical-device log verification
