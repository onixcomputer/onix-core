# Proposal: Harden the ttWKV7 reader diagnostic loop

## Why

The sole authorized data-movement process validated both reviewed writer-scatter paths but produced only partial reader evidence. The chunked reader was launched with an invalid runtime vector (`L=1` instead of fixed chunk size `L=32` with `Lreal=1`), while the decode reader reported exactly half of 143360 compared elements mismatching. Existing device-free tests validate wrapper dispatch and layout oracles but do not validate the production reader's positional runtime ABI, the CB21 capture path independently, uploaded input/state page order, or raw post-run artifacts.

A corrected diagnostic must catch ABI drift without hardware and make one later process sufficient to distinguish diagnostic infrastructure, host packing, capture, production reader, partial-tail, and writer failures.

## What Changes

- Replace ad hoc reader runtime-argument assembly with a pure typed serializer and exact positive/negative 18-field fixtures.
- Add an architecture-checked CB21 source peer and independent tagged capture-loopback, input-upload, and flat-state-upload controls.
- Exercise decode length 1, chunked `L=32/Lreal=1`, and chunked `L=32/Lreal=32` as distinct reviewed cases.
- Emit mismatch breakdowns by input/state region, tile, row, face, and head instead of only total and first mismatch.
- Persist raw bf16 captures, exact runtime vectors, and a deterministic manifest under the reviewed Metalium log directory.
- Extend package checks, dual-architecture compilation, host closure, and Cairn evidence without accessing hardware.

## Completion Boundary

Completion is device-free only. The current known-bad vector must fail a negative fixture, every exact ABI/control/oracle/package/architecture check must pass, and the owner must remain untouched. No physical process, compatibility claim, or reuse of the exhausted authorization is permitted. A later device run requires a separate Cairn change and explicit authorization.
