# Design: Aspen1 Radicle forge CI

## Approach registry

| Family | Mechanism | State | Reason |
|---|---|---|---|
| production control subscription | Subscribe through Aspen's seed control socket and read seed storage | rejected | The control socket accepts mutating node commands, storage contains the machine profile, and the event stream has no durable replay. |
| production storage polling | Run a scanner directly as the `radicle` seed user | rejected | A compromised scanner could read the node key, write canonical/storage refs, or alter the production seed policy. |
| separate bot plus spool | A non-delegate CI node fetches only the admitted RID, exports exact objects, and a credentialless runner consumes an immutable spool | selected | It preserves event recovery while separating network/status identity from untrusted execution and production seed authority. |

## Components

### Pure admission core

The core validates the typed policy, exact RID, signed-reference feature,
delegate set, trigger shape, Git object IDs, patch/revision linkage, unchanged
lockfile identities, spool names, deduplication state, bounded observations, and
status claim scope. It performs no file, process, network, clock, or credential
I/O.

### CI bot shell

A dedicated `radicle-forge-ci-bot` system user owns a separate Radicle home and
machine-scoped Ed25519 identity. Its node listens only on loopback, connects only
to Aspen's production seed, default-blocks replication, and seeds exactly the
pilot RID. It is not a project delegate.

A timer synchronizes only the pilot RID, opens the bot's local Radicle storage,
lists open patch revisions through Heartwood's read-only APIs, and exports each
new exact Git object as a source archive plus typed event. The durable processed
ledger makes scans idempotent after restart. Canonical branch/tag scanning uses
the same exact-object path.

### Credentialless runner

A distinct `radicle-forge-ci-runner` user receives only admitted event/archive
pairs through a group-bounded exchange. It cannot read the bot home, production
Radicle state, `/run/secrets`, user homes, deployment material, or cache signing
keys. `PrivateNetwork` denies job networking.

The runner verifies the event and archive identity, materializes a read-only job
directory, copies already-locked flake inputs into a per-runner local Nix store
in offline mode, and invokes the accepted Nix command through `bounded-exec`.
The isolated store cannot publish to Harmonia or write the host shared cache.
CPU, memory, time, output, process, and artifact limits are enforced by both the
pure plan and systemd.

### Status publisher

The bot consumes completed typed results, writes a BLAKE3-bound receipt, and for
patch triggers publishes a concise comment on the exact patch revision under its
own DID. The bot may create only its own COB operations and signed namespace;
its DID is checked not to be in the project delegate set. The runner never sees
the bot key or control socket.

## Failure behavior

Malformed events, wrong RIDs, unknown objects, changed lockfiles, stale patch
heads, duplicate jobs, source archive mismatch, excessive output, timeout,
cancellation, runner failure, artifact failure, and status failure remain
explicit outcomes. Failed status publication leaves the result in the outbox
for retry. No failure may mutate a canonical ref or production seeding policy.

## Deployment and rollback

Onix Core lowers the typed service onto Aspen1 and builds the full machine before
deployment. Deployment is accepted only after identity pairing, non-delegate
verification, exact policy, service hardening, a successful canonical job, an
actual patch job and status comment, restart deduplication, negative authority
probes, and unchanged production seed/public-Git behavior.

Rollback disables the CI timers, runner, publisher, and bot node, then removes
only CI-owned state after retaining receipts. It does not alter the production
seed or canonical RID.
