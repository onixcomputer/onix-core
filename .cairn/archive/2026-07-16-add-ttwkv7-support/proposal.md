# Proposal: Add ttWKV7 support

## Summary

Add a reproducible `ttwkv7` package for `x86_64-linux`, expose it on Tenstorrent-tagged hosts, and document the exact runtime compatibility boundary.

## Motivation

The repository already pins a native TT-Metalium runtime, but operators cannot build or invoke Marty1885's standalone RWKV-7 WKV7 operator without an unmanaged source checkout and network-enabled CMake dependency fetching. The upstream executable also resolves JIT kernel paths relative to its working directory, which makes a binary-only installation incomplete.

## Scope

- Package upstream revision `84d8b6a44729cc358f163e7ab9614b0a1b8ddc09` without build-time network access.
- Link against the repository's pinned `tenstorrent.nix` TT-Metalium package through its installed CMake target.
- Install the host executable together with all runtime JIT kernel sources and wrap invocation so relative kernel paths resolve deterministically.
- Expose the package through the flake and Tenstorrent host closure.
- Document that upstream currently describes and benchmarks Wormhole only; packaging does not by itself establish Blackhole P150 correctness.
- Classify the package as unfree while upstream has no declared license.

## Non-goals

- Port or tune the kernels for Blackhole.
- Claim validated P150 or P150x2 runtime support without device execution evidence.
- Start a persistent service or automatically acquire/reset an accelerator.
- Modify firmware or stop existing model services.

## Risks

The upstream source is young, has no declared license, and targets a different accelerator generation than the managed P150 host. The integration therefore separates reproducible package support from hardware compatibility claims and keeps device tests manual and isolated.

## Requirements

- r[onix.tenstorrent.native_runtime.ttwkv7.package]
- r[onix.tenstorrent.native_runtime.ttwkv7.host]
- r[onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary]
