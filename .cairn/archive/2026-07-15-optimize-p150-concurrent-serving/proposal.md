## Why

The two isolated P150 services remain correct under simultaneous load, but the first synchronized probe reduced Supra-Router-51M from 156.44 to 59.95 decode tokens/s while VibeThinker delivered 19.30 tokens/s. Both processes currently span all 32 logical CPUs and each owns 89 runtime threads on a single-socket Ryzen 9 9950X3D with two eight-core L3/CCD domains. The deployment needs measured concurrent scheduling rather than speculative CPU pinning, firmware changes, or a model-quality trade-off.

## What Changes

- Add a deterministic benchmark harness that records isolated and synchronized concurrent decode throughput and rejects malformed or failed responses.
- Compare materially distinct contention mechanisms: llama.cpp thread budgets, CCD-aware CPU placement, PCIe/power pressure, and cross-process Metalium runtime behavior.
- Deploy only a candidate that materially improves repeated concurrent throughput without regressing isolated service throughput or required output behavior beyond the declared tolerance.
- Record the validated boundary in focused Nix checks and the Tenstorrent operator guide; leave the current configuration unchanged if every bounded candidate is falsified.

## Impact

- **Files**: `scripts/benchmark-p150-concurrent.rs`, Metalium service configuration, focused machine checks, Tenstorrent operator documentation, and this Cairn change package
- **Testing**: benchmark harness positive/negative self-tests, five-run isolated and synchronized baselines, bounded candidate trials, focused Nix checks, complete `britton-desktop` build, runtime health/journal checks, and Cairn gates
