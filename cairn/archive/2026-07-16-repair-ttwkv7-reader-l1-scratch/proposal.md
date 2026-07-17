# Proposal: Repair ttWKV7 reader L1 scratch

## Why

The sole aligned-reader hardware process passed every control but hung after committing the first production decode-reader workload. Its compiled BRISC ELF proves the supposedly L1 scratch array is an aligned local stack object in private LDM near `0xffb00ce0`, and the generated kernel writes that private address into the NoC destination register. TT-Metal's reviewed misaligned-read implementations instead stage through worker-L1 addresses obtained from circular buffers.

## What Changes

- Replace both production readers' local stack scratch arrays with one Blackhole-only reserved page from otherwise-unused CB22.
- Align the CB write pointer to the pinned NoC DRAM-read boundary before staging each 64-byte block.
- Preserve Wormhole's direct 32-byte read path without reserving scratch or changing CB cadence.
- Extend the device-free architecture gate to require CB-backed scratch, reject stack-backed scratch, verify host allocation, and retain positive and negative checks.

## Completion Boundary

Completion proves source ownership, bounds, host allocation, and Blackhole/Wormhole compilation without contacting hardware. It does not prove that the corrected reader completes on a P150, validate WKV arithmetic, authorize another device process, or broaden compatibility claims.
