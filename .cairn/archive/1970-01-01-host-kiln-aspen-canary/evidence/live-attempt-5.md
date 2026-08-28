# Live attempt 5: direct rollback poll exhaustion

Date: 2026-08-28

## Verdict

PASS for accepted completion, exact replay, denied completion, unavailable endpoint, and disconnect-after-write uncertainty.

FAIL for a fresh direct Lattice rollback reaching success within 64 tight polls. The adapter returned the exact terminal classification `timed_out`; it did not select another runtime.

## Deployed closure

`/nix/store/vpzd8xjrn2x4vqjn4b2qbyzn5ai6xjd9-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

## Passing receipt identities

- accepted and exact replay: `884a5f1f9c49392bf839fe7fb7e28888c808cfd2706e05bb5ad56f4c9d45fe77`
- rejected: `301ae4db3c79729497aa0269d6b298bcbc180388b227d847cd8be3a9f7b38dbf`
- unavailable without fallback: `495d901c518912c2c30d548904a83edee4dc35e12acc4e04a5902818196d3276`
- unknown after provider write and exact unknown replay: `231eacd656e9d62c25e47d90a655c8c34413873aa0d831fa0d8aeb0c3b855435`

Both long-lived services remained active after the uncertainty drill. The Lattice socket was restored with owner `kiln-aspen-canary-lattice` and mode `0660`.

## Direct rollback observation

The explicit `--runtime lattice` unit returned `timed_out` with receipt identity:

`27fac940ad173334c7094e289835f0a9d1e6f8799f6de04475d1011e63207291`

This is an honest provider observation, not fallback.

## Correction

Allocate Lattice's maximum connection count across the admitted host request count.

For 64 host requests, each effect receives 1024 connections: one dispatch and 1023 observations. The total remains exactly within the Lattice contract maximum of 65536 connections.

The larger bound does not prove workflow success or performance. It only prevents the client from exhausting its admitted observation budget before a bounded local workflow can finish.
