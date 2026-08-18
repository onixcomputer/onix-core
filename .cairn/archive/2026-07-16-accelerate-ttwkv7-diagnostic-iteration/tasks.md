## Phase 1: Baseline and lifecycle gates

- [x] [serial] Establish passing package, accelerator-inventory, machine-closure, and Cairn baselines without device access. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
- [x] [serial] Gate the proposal, design, and task graph before implementation. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]

## Phase 2: Focused package lane

- [x] [serial] Split pinned ttWKV7 host binaries, immutable JIT kernels, and runtime wrappers into independently cached derivations. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
- [x] [serial] Add positive and negative no-device probe-runtime preflight coverage for writable paths and loopback Inspector addressing. r[onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state]
- [x] [serial] Add pinned Blackhole and Wormhole math-kernel compilation checks for all three affected compute sources. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]

## Phase 3: Host decomposition and integration

- [x] [serial] Decompose the Tenstorrent tag behind its registry-visible shim without changing evaluated host behavior. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
- [x] [serial] Document exact store-path diagnostic iteration while preserving the no-retry and separate-authorization boundary. r[onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state]
- [x] [serial] Run package, architecture, inventory, machine-closure, Cairn, and formatting gates without hardware access. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
- [x] [serial] Sync accepted requirements and archive the completed no-device change. r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration]
