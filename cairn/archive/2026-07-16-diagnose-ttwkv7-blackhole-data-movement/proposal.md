# Proposal: Diagnose ttWKV7 Blackhole data movement

## Why

The exact Blackhole cross-kernel control produced nearly identical severe numerical failures from the chunked and decodeL reader/compute paths, while all 14 constant-generator cases passed exactly. The next smaller discriminator must separate shared reader/upload and writer/scatter behavior from WKV arithmetic without relaxing tolerances or consuming another unreviewed device process.

## What Changes

- Add a package-owned no-WKV data-movement executable with pure host oracles and a device-free `self-test` mode.
- Capture the exact chunked and decodeL reader streams into contiguous DRAM without a compute kernel and compare uniquely tagged input/state placement.
- Feed uniquely tagged output/state tiles directly into the exact production writer and compare the complete scattered host matrix, including untouched sentinel rows.
- Add an immutable runtime wrapper that fixes device 1 and rejects caller-controlled arguments or unsafe runtime state before any device access.
- Compile new data-movement kernels offline for pinned Blackhole and Wormhole toolchains and retain positive and negative oracle fixtures.

## Scope

This change implements and validates the diagnostic boundary without hardware. It does not claim broad P150 compatibility, alter WKV arithmetic, change tolerances, rerun the exhausted cross-kernel command, or authorize a physical process. A future launch requires a committed executable one-shot and explicit authorization for exactly one device-1 data-movement process.
