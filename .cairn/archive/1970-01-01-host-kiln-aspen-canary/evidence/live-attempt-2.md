# Live attempt 2: stale host socket

Date: 2026-08-28

## Verdict

FAIL for service restart. PASS for fail-closed socket admission.

## Observations

Clan activated the corrected connection-budget closure:

`/nix/store/jad9cdjwg6x1b3k9z8pmpacw3mdnhs1w-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

The Lattice service restarted with the derived connection bound. The host service stopped before replacement, but its Unix socket remained in the shared runtime directory.

The new host process rejected startup with:

`host I/O failed: Aspen host socket path already exists`

No process replaced or followed the existing path. This is the required fail-closed behavior for the host binary, but the deployment shell lacked a safe restart step.

## Correction

Add a host `ExecStartPre` helper with these rules:

1. Continue if the exact Aspen socket path is absent.
2. Fail if that exact path exists and is not a Unix socket.
3. Remove only that stale Unix socket after systemd has stopped the old host service.
4. Never inspect or remove the Lattice socket.

The helper runs as the unprivileged host user inside the existing hardening and writable-path boundary.
