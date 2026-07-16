# Design: Fix ttWKV7 Blackhole reader gather alignment

## Goal and Evidence

Eliminate every architecture-invalid 32-byte Blackhole DRAM face-row gather in both production readers while preserving exact Wormhole behavior. Completion evidence is a shared helper with compile-time alignment proofs, negative static checks, pinned Blackhole/Wormhole reader compilation, unchanged ABI fixtures, package checks, and host closure without device access.

A compiling branch that still emits a 32-byte Blackhole DRAM transaction, a full-tile replacement that changes CB cadence, a Wormhole regression, relaxed numerical comparison, or another physical process is false completion.

## Root Cause

Pinned Blackhole `noc_parameters.h` defines `NOC_DRAM_READ_ALIGNMENT_BYTES=64`; pinned Wormhole defines 32. Metalium's sanitizer requires the local destination and remote NOC address to have matching alignment residues. The readers use 32-byte reads for each 16-element tile face row. Source and destination face-row offsets advance by 32 bytes, so Blackhole receives invalid residue combinations whenever the independently selected source and destination rows differ modulo two.

The physical evidence matches that mechanism: state destination odd rows fail exactly, input failures follow source-head and destination-token parity, both readers share the pattern, and full-tile controls bypassing sub-page gathers pass.

## Functional Core and Imperative Shell

The pure core is a constexpr alignment plan:

- align a face-row source offset down to the architecture DRAM-read boundary;
- retain the selected byte remainder;
- prove aligned offset plus remainder reconstructs the original offset;
- prove the selected 32-byte interval fits in one aligned transaction.

The imperative helper executes that plan. On Blackhole it reads one aligned 64-byte block into a 64-byte-aligned L1 scratch array, waits for completion, and copies the selected eight 32-bit words into the exact destination face row. On Wormhole it retains the existing asynchronous direct 32-byte read; the existing outer barrier and CB cadence remain unchanged.

Both production readers allocate one bounded scratch block and call the same helper for input and state face rows. Tail neutralization remains local and unchanged.

## Approach Registry

| Family | Mechanism | Claim | Gap | State |
|---|---|---|---|---|
| Aligned scratch | Read one aligned architecture block, then local-copy selected face row | Satisfies Blackhole alignment without changing CB layout | Simpler | selected |
| Full-tile staging | Read every source tile, then select locally | Satisfies alignment | Stronger traffic/L1 change | rejected |
| Destination pairing | Read 64 bytes directly into two output rows | Avoids scratch | Cannot represent rows sourced from different pages | falsified |
| Keep 32-byte reads | Rely on observed Wormhole behavior | Preserves performance | Violates pinned Blackhole contract and evidence | falsified |

## Offline Implementation Evidence

The helper is installed as `ttwkv7_aligned_dram_face_read.h` and both patched production readers have exactly four helper call sites, no direct `noc_async_read` calls, and unchanged two-site reserve/push cadence. Compile-time evaluation checks all 64 row/column-face offsets for reconstruction and in-block selection, plus an invalid interval. The Blackhole branch emits aligned architecture-sized reads, barriers, and bounded eight-word local copies; the Wormhole branch retains direct asynchronous 32-byte reads.

Package `/nix/store/4d6syhgiq81md3m9np6j39qdaa6rl8rj-ttwkv7-unstable-2026-06-22`, kernels `/nix/store/fda5gkrr1klpk5ha49yih1myk5sni78p-ttwkv7-kernels-unstable-2026-06-22`, architecture check `/nix/store/d65lsbfrkrzmxn4877z2d2060ggazrqb-ttwkv7-architecture-check`, and host closure `/nix/store/6c2samz52yfvf8pj2ghhrl8lwpfr4ki5-nixos-system-britton-desktop-26.11.20260629.7a1a647` build without device access. The architecture output contains both production readers as BRISC objects for Blackhole and Wormhole, and the package oracle self-test passes.

## Adversarial Audit

The selected aligned-scratch mechanism is bounded to one architecture block for the full kernel lifetime. Blackhole barriers complete each read before scratch reuse or local copy. Every selected source interval is inside one aligned block; every destination is written by local 32-bit stores rather than a misaligned NOC transaction. Wormhole offsets are already multiples of its 32-byte requirement, so aligned offsets are unchanged and the existing outer barrier remains authoritative.

The audit found one real test-shell defect: a negative cadence mutation ran the checker in an `if` condition, which suppresses Bash `errexit`, allowing failed `test` commands to fall through. Each invariant now returns failure explicitly, and both direct-gather and cadence mutations are rejected. Advisory concerns about destination 64-byte alignment do not apply to local CPU stores; concerns about unchecked offsets are covered by exhaustive constexpr evaluation. The device-1 owner remains active/running with `Result=success`, `NRestarts=0`, and HTTP 200. Residual uncertainty is physical Blackhole execution and performance only.

## Validation and Authorization Boundary

Compile-time assertions cover offsets in both halves of each tile face and architecture read sizes. Static package checks require both readers to include and call the helper, reject direct 32-byte NOC gathers in the patched readers, and require the helper's Blackhole aligned read plus local copy. Architecture checks compile the helper through both readers as NCRISC for pinned Blackhole and Wormhole.

No Tenstorrent device may be enumerated, initialized, opened, stopped, or contacted. A future physical test requires a new Cairn change, immutable package/runbook, zero-state boundary, healthy independent restoration, and fresh exact authorization.
