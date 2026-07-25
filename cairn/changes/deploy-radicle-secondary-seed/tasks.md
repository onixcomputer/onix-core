## Phase 1: Typed replica boundary

- [x] [serial] Add the typed secondary-seed schema, host/failure-domain validation, pure lowering, dedicated node-key generator, runtime fingerprint verification, and bounded state dataset. r[onix.radicle_replica.configuration]
- [x] [parallel] Add positive module checks and negative fixtures for host, target, identity, listener, repository, monitoring, storage, ingress, and forbidden-authority failures. r[onix.radicle_replica.validation]

## Phase 2: Deployment and synchronization

- [ ] [serial] Generate and pin the distinct replica node identity, create the bounded dataset, deploy to `britton-desktop` through its pinned tailnet host key, and reconcile exactly the pilot RID. r[onix.radicle_replica.deployment]
- [ ] [parallel] Verify service hardening, listener/firewall scope, restart continuity, exact repository/object storage, monitoring, and absence of delegate/CI/deployment/release/cache authority. r[onix.radicle_replica.authority]

## Phase 3: Independent availability evidence

- [ ] [serial] Stop Aspen1's native node and prove an egress-confined independent client acquires the exact pilot object from the desktop replica without public-seed or GitHub fallback, then restore Aspen1. r[onix.radicle_replica.availability]
- [ ] [parallel] Prove undeclared RID, missing object, wildcard listener, HTTP exposure, and write/authority attempts fail closed. r[onix.radicle_replica.availability]
- [ ] [serial] Emit the deterministic redaction-safe deployment receipt, pass focused Nix/Cairn validation, and archive only after OnixOS verifies the receipt. r[onix.radicle_replica.evidence]
