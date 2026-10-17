# Verification: Kiln source refresh stabilization

## Static and fixture verdict

**PASS.** Deployment and the final Seaglass replay are complete.

## Focused module check

`nix build .#checks.x86_64-linux.kiln-aspen-radicle-ci-module --no-link -L` passed.

The check now requires:

- current ACL inspection through `getfacl`;
- conditional directory ACL updates;
- conditional file ACL updates;
- the existing symlink, file-type, source-path, group, capability, and no-network boundaries.

The check rejects the old unconditional `find ... -exec setfacl` form.

## Generated command fixture

The evaluated production admission command was copied to a temporary fixture. Only its source root and group were replaced.

Positive results:

- a first run added missing directory access, directory default, and file access ACLs;
- a second run left directory and file change timestamps unchanged.

Negative result:

- a source tree containing a symbolic link failed with the expected admission diagnostic.

## Machine and lifecycle checks

- Complete `britton-desktop` system closure build: PASS.
- Nix formatting check for both changed Nix files: PASS.
- Proposal, design, and tasks gates: PASS.
- Repository Cairn validation: PASS.

## Deployed path recovery

- Active system closure: `cd9cfva8zm04ff7hxnrzm5s4ik3hs372-nixos-system-britton-desktop-26.11.20260819.afe3d8a`.
- Active refresh unit uses the idempotent admission script.
- Manual refresh result: success.
- Settling interval: one refresh invocation only.
- Path state after settling: active and waiting.
- Path result after a new Seaglass push: success and still waiting.
- Source-refresh journal after that push: one successful invocation.

## Live replay

The final Seaglass replay used exact revision `fed0072ab0aac001187e79a4d82bec9b8286598b`.

Observed results:

- source-refresh invocations after push: one;
- path state after refresh: active and waiting;
- provider schema: `kiln.radicle-nix-provider.v1`;
- provider outcome: success;
- provider exit code: `0`;
- source-readiness exhaustion diagnostic: absent;
- terminal report revision: exact match;
- broker queue after completion: empty;
- Qwen and Traefik services after activation recovery: active with zero restarts.

Raw receipts and service observations remain under `/home/brittonr/git/onix-core/.pi/stabilize-kiln-source-refresh-20260904/`.

## Lifecycle closeout

- Accepted spec: `.cairn/specs/kiln-aspen-radicle-ci/spec.md`.
- Archive: `.cairn/archive/2026-09-04-stabilize-kiln-source-refresh`.
- Archive receipt: `9496b31fd8f1a8e316241decfa1d88916189cac2202ca7edbae9fc6511abe505`.
- Post-archive Cairn validation: PASS.

## Non-claims

- Static checks do not prove deployed service recovery.
- Fixture quiescence does not prove arbitrary filesystem or inotify behavior.
- Source visibility does not prove CI correctness or release eligibility.
