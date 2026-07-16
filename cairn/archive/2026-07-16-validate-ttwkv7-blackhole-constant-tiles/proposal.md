## Why

The first Blackhole SFPU port removed ttWKV7's compile-time architecture blocker, but its only P150 execution failed the CPU oracle with output/state normalized mean-square errors near one. The port currently finishes custom SFPU generation with Blackhole's minimal `_llk_math_eltwise_sfpu_done_()`, which omits the stall and C16 reset performed by the upstream epilogue, while the pinned Blackhole LLK provides `_llk_math_eltwise_sfpu_done_with_addrmod_reset_()` for that lifecycle. Compilation alone cannot establish whether the seven generated constant tiles are correct.

## What Changes

- Preserve the pinned LLK's architecture-specific SFPU finalization semantics in both chunked and decode constant generators without calling Wormhole-only primitives on Blackhole.
- Package a bounded constant-tile probe with a pure CPU oracle, positive and negative self-tests, and exact comparison of every generated 32-by-32 chunked mask at lengths 1 and 32.
- Compile the relevant Blackhole and Wormhole JIT paths offline before deployment.
- Deploy an exact reviewed revision and perform one isolated device-1 probe invocation with no retries, guaranteed owner-service restoration, and board-health evidence.
- Record the measured boundary without claiming full P150 WKV compatibility.

## Impact

- **Files**: `pkgs/ttwkv7/`, `inventory/tags/tenstorrent.nix`, and `cairn/changes/validate-ttwkv7-blackhole-constant-tiles/`
- **Testing**: package install checks, pure probe self-tests, offline Blackhole and Wormhole JIT compilation, accelerator inventory and machine closure builds, Cairn gates, one bounded P150 probe, service recovery, and TT-SMI health checks
