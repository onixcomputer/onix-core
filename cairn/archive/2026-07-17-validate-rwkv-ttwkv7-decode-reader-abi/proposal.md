## Why

The accepted real-weight host-layout check proves that exact BF16 fixture bytes reach ttWKV7's production tiled input and retained-state buffers, but it stops before the decode reader's runtime ABI and sub-page gather formulas. The existing data-movement oracle covers a synthetic 32-head shape and does not bind the 12-head checkpoint, the accepted real bytes, or production's exact decode reader/compute/writer argument vectors. The next device-free rung should close that source-level seam without changing production kernels or claiming device execution.

## What Changes

- Extract production decode reader, compute, and writer runtime-argument construction into a shared pure C++ header used by the runner and a no-device validator.
- Add a strict real-fixture decode-reader validator that rebuilds the accepted transformed input/state buffers, emulates the unchanged production reader's source-page and tiled-face gathers for all 12 logical heads, and compares complete meaningful CB payloads against an independently constructed logical oracle.
- Add deterministic BLAKE3 receipts for exact runtime vectors, source-page/face traces, state payloads, input payloads, and their domain-separated combination.
- Add a cross-package Nix check that pins fixture, transformed-buffer, runner, and reader-source authorities; rejects malformed fixtures, ABI drift, gather mutations, and command suffixes; and keeps the fixture outside ttWKV7's runtime closure.
- Preserve all historical host-layout, shape, architecture, and synthetic data-movement evidence.

## Impact

- **Files**: ttWKV7 pure host headers, runner patch/build/runtime packaging, a new decode-reader validator and Nix check, `flake-outputs/ttwkv7.nix`, and this Cairn package
- **Testing**: pre/post package and cross-package checks, exact deterministic receipts, positive and negative gather/ABI fixtures, dual-architecture kernel compilation, historical host-layout and data-movement checks, focused formatting/linting, and clean Cairn validation/gates
