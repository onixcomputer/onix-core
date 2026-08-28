# Live attempt 1: bounded connection exhaustion

Date: 2026-08-28

## Verdict

FAIL for accepted terminal completion. PASS for fail-closed uncertainty and no automatic fallback.

## Deployment

Clan activated system closure:

`/nix/store/v1h6i4xslpahly6z5d6p9q9fmn517fp8-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

The deploy built on `localhost` and uploaded the closure because the target has no authority to fetch private Cargo Git sources.

The first activation reported existing ZFS quota and cache-directory quota failures. Clan retried. The target then reported the same closure as current, and both canary services were active.

## Observations

- `kiln-aspen-canary-host.service` ran as `kiln-aspen-canary-host`.
- `kiln-aspen-canary-lattice.service` ran as `kiln-aspen-canary-lattice`.
- The state roots had separate owners and mode `0700`.
- The shared runtime directory had mode `0770`.
- The accepted operator request returned `aspen_ingress_unknown`.
- No fallback runtime was selected.
- The host log reported `lattice_transport_connect` after Aspen accepted the operation.
- Lattice stopped cleanly after 64 accepted connections and 64 completed exchanges.

## Root cause

The host admits one Lattice dispatch followed by at most 64 observation polls. The Lattice server admitted only 64 total connections.

A worst-case effect therefore needs 65 connections. The server stopped before the last admitted observation request.

## Correction

Derive the Lattice server connection bound from:

`maximum host requests * (one dispatch + maximum provider polls)`

For the reviewed canary, the result is `64 * 65 = 4160`. The typed profile must reject values above Lattice's contract maximum of `65536`.

Restart both long-lived services after redeployment. The accepted-but-unacknowledged operation is process-local state, so this restart does not prove durable active-operation recovery.
