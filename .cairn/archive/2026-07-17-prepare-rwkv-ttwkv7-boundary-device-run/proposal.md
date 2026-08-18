## Why

The accepted real-weight boundary, host layout, and decode-reader ABI now reach the exact production kernel launch seam, but the production runner still generates random inputs, performs repeated timing launches, and exposes only aggregate metrics. A future authorized hardware attempt would therefore fail to consume the accepted retained-state fixture or preserve complete raw output/state evidence. The harness and its pass/fail contract must be finalized without device access before another attempt can be considered.

## What Changes

- Add a strict fixture-only mode to the existing production `wkv7` execution path for the accepted `G=1`, `L=1`, `S=64`, `H=12` decode boundary.
- Reuse the accepted host-layout and decode-ABI cores, unchanged production reader/compute/writer kernels, and one workload enqueue while preserving complete raw writer, output, and post-state BF16 evidence.
- Add a separate fixture-bearing hardware-boundary package, fixed wrapper, typed `rwkv-lab` plan, deterministic no-device self-tests, preset numerical criteria, adversarial controls, and explicit no-authorization status.
- Keep the ordinary ttWKV7 runtime closure free of the fixture, checkpoint, layer harness, safetensor, and PyTorch, while retaining its pre-existing Metalium Python runtime without adding another Python closure path.

## Impact

- **Files**: `pkgs/ttwkv7/`, a separate RWKV/ttWKV7 boundary package, `flake-outputs/ttwkv7.nix`, and Cairn lifecycle artifacts.
- **Testing**: positive and negative fixture/parser/comparator tests, exact wrapper/plan checks, package and closure checks, historical host-layout/decode-reader/shape/data-movement/architecture regressions, formatting, and clean Cairn gates. No hardware command is executed.
