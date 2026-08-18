# Deploy the Radicle forge CI runner

## Problem

The accepted OnixOS Radicle CI policy and pure broker shell are not deployed.
Aspen1 hosts the selective seed and public read-only Git adapter, but no service
currently turns admitted Radicle patch objects into bounded Nix observations or
publishes a bounded status. Running untrusted jobs in the seed profile would
expose the seed control socket, storage, and machine identity.

## Outcome

Deploy a separate CI bot node and credentialless runner on Aspen1. The bot may
fetch the one admitted RID and publish patch comments under its own non-delegate
identity. It exports immutable exact-object source archives into a bounded
spool. The runner has no network, Radicle profile, delegate key, deployment
credential, shared-cache write path, seed storage, or production seed control
socket. It builds through an isolated local Nix store and emits BLAKE3-bound
artifacts and status facts for the bot publisher.

## Scope

- typed Nickel service policy and deterministic NixOS lowering;
- an exact-RID scanner and restart-safe deduplication core;
- bounded-exec-backed Nix execution in a separate runner identity;
- a CI bot identity that is not a project delegate;
- local artifact/status evidence and patch-comment publication;
- monitoring, positive/negative fixtures, deployment, restart, and patch drills.

## Non-goals

This change does not grant merge, canonical-ref, release, deployment, production
seed-policy, shared-cache-write, or delegate authority. It does not prove host
sandboxing, Nix or source correctness, artifact durability, mandatory-CI merge
enforcement, automatic failover, release readiness, or private-repository
confidentiality.
