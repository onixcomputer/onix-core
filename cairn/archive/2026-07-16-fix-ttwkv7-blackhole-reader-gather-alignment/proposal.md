# Proposal: Fix ttWKV7 Blackhole reader gather alignment

## Why

The complete single-process reader diagnostic passed CB21 capture, all input/state upload controls, and both writers, while decode and both chunked reader cases failed in systematic half-layout patterns. Pinned Metalium requires 64-byte Blackhole DRAM reads but only 32-byte Wormhole DRAM reads. Both production readers issue 32-byte face-row gathers whose source and destination alignment residues independently alternate between zero and 32 bytes, matching the observed odd-row and half-head failures.

## What Changes

- Introduce one architecture-aware face-row gather helper shared by the chunked and decode readers.
- Preserve direct 32-byte Wormhole reads while staging Blackhole-aligned 64-byte reads into aligned L1 scratch and copying the selected 32-byte face row locally.
- Add compile-time alignment-plan assertions and source checks that reject direct production-reader 32-byte DRAM gathers on Blackhole.
- Compile both production readers and all diagnostic peers for pinned Blackhole and Wormhole toolchains.
- Preserve the terminal evidence and require a new lifecycle and authorization before physical validation.

## Completion Boundary

Completion is device-free. Every Blackhole source NOC address and scratch destination must satisfy the pinned 64-byte DRAM-read contract, Wormhole source order and 32-byte transfer semantics must remain unchanged, and package, architecture, host, formatting, pre-commit, and Cairn gates must pass. No physical correctness or broad P150 compatibility claim is made.
