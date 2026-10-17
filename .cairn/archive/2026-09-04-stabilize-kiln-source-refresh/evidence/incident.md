# Incident evidence: Kiln source refresh start-limit loop

## Observed event

- Date: 2026-09-04.
- Repository: private Seaglass Radicle source.
- Event revision: `7c7483822fa2b90063974fc012b1a91785d6e3f4`.
- Broker admission: accepted the exact RID, default branch, and `flake.nix` filter.
- Provider result: terminal failure before Nix execution.
- Stable failure class: `provider source revision did not become visible before its bound`.

## Host state

`kiln-aspen-ci-source-refresh.path` reported:

- `ActiveState=failed`;
- `Result=unit-start-limit-hit`.

`kiln-aspen-ci-source-refresh.service` reported:

- `ActiveState=failed`;
- `Result=start-limit-hit`.

The journal recorded repeated successful one-shot runs in the same second. The sixth start hit the service limit.

## Root cause

The admission script called `setfacl` for every directory and file on every run. Attribute writes produced new events under the `PathModified` watch. The service therefore retriggered itself after the ACL state was already current.

## Operational boundary

A direct reset was attempted with non-interactive sudo. The host required a password, so no service state changed.

Raw provider and systemd observations remain in:

`/home/brittonr/git/onix-core/.pi/stabilize-kiln-source-refresh-20260904/`

This evidence proves the observed loop and source-readiness failure only. It does not prove the fixed closure is deployed.
