# Proposal: Validate ttWKV7 Blackhole reader gather alignment

## Why

The complete reader diagnostic localized deterministic parity corruption to 32-byte production-reader DRAM gathers that violate Blackhole's pinned 64-byte read alignment. The device-free fix now stages aligned 64-byte blocks through bounded L1 scratch on Blackhole while preserving Wormhole's direct path. Physical correctness remains unproven and the previous authorization is exhausted.

## What Changes

- Freeze the corrected package, kernels, active system, device selector, wrapper vector, and clean commit in a fresh executable one-shot.
- Require exact fresh authorization, an atomic persistent attempt lock, zero counters, strict loopback trust, and independently armed owner rollback.
- Run the same thirteen high-information controls/readers/writers exactly once so results compare directly with terminal evidence.
- Preserve and hash raw bf16 captures, runtime vectors, manifest, process, owner, rollback, and board evidence.

## Completion Boundary

Completion is one terminal process or an exact blocker. No retry, fallback, suffix, direct-runtime command, performance claim, or broad P150 compatibility claim is permitted.
