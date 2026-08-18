# Proposal: Localize the ttWKV7 Blackhole numerical mismatch

## Why

The selected Blackhole P150 executes the chunked `G=1,L=1` workload but disagrees strongly with the CPU oracle, while all fourteen reviewed constant tiles now pass exactly. The failure must be localized before changing arithmetic, transfer code, or compatibility claims.

The pinned executable can compare its chunked and decodeL implementations at the same deterministic shape inside one device-owning process. That is the smallest discriminating check: both paths share host inputs, output allocation, writer scatter, final host extraction, and CPU oracle, while using different readers and compute kernels.

## What Changes

- Add a package-owned diagnostic command that accepts only `validate-runtime` or an exact cross-kernel diagnostic mode.
- Require writable Metalium cache/log paths and an unused loopback Inspector address before diagnostic dispatch.
- Dispatch the immutable packaged runtime with exactly `test all 1 1` and no caller-controlled suffix.
- Prove the production argument vector with positive and negative device-free tests.
- Retain the pinned-source and official Tenstorrent debugging research that selects this check ahead of DPRINT, checkpoints, Watcher, or invasive intermediate snapshots.
- Keep any physical comparison behind a fresh committed one-shot and separate explicit authorization.

## Impact

- **Files**: `pkgs/ttwkv7/`, this Cairn change, and the accepted Tenstorrent native-runtime specification after sync.
- **Testing**: baseline package and architecture checks; exact wrapper-vector tests; package, dual-architecture, host-closure, formatting, pre-commit, and Cairn gates; no hardware during implementation.
- **Runtime**: if separately authorized, one process on selected device 1 runs exactly the chunked and decodeL `G=1,L=1` cases, then terminates without retry.
- **Claims**: the comparison may localize the mismatch family, but cannot by itself establish full-WKV, decode, performance, or general P150 compatibility.

## Requirements

- r[onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic]
