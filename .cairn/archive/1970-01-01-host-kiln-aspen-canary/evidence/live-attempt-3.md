# Live attempt 3: stale Lattice socket

Date: 2026-08-28

## Verdict

FAIL for Lattice service restart. PASS for preserved service dependency ordering.

## Observations

Clan activated system closure:

`/nix/store/0iay9mzmysczwbc0hq05y9532y84pj30-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

The Aspen stale-socket guard was present. Lattice stopped before replacement, but its own Unix socket remained in the shared runtime directory.

The replacement Lattice process returned `workflow exchange transport failed`. Its configured `Restart=on-failure` repeated the same fail-closed result. The required host service did not start while Lattice was unavailable.

## Correction

Use the same narrow stale-socket guard component for both service-owned paths.

- The Lattice guard runs before workflow preparation.
- The Aspen guard remains separate.
- Each guard accepts only its exact Unix socket path.
- Cross-socket checks prove that neither guard contains the other service's path.
- A non-socket path still fails closed.

This evidence does not claim successful restart or deployment readiness.
