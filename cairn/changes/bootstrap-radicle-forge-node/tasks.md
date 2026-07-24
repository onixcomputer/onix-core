## Phase 1: Typed package and service boundary

- [x] [serial] Pin and package the reviewed Radicle node and HTTP components at the named minimum version, recording source and closure identities. r[onix.radicle_node.package]
- [x] [serial] Add the typed Nickel bootstrap-node contract and deterministic Nix lowering for host selection, failure domain, storage, selective seeding, native listeners, local-only HTTP, signed-reference acquisition policy, and later HTTPS activation. r[onix.radicle_node.configuration]
- [x] [parallel] Add positive configuration fixtures and negative fixtures for old versions, weak signed-reference policy, missing host/failure-domain facts, unsafe listeners, port collisions, credential scope, malformed endpoints, invalid repository IDs, and duplicate repository IDs. r[onix.radicle_node.configuration]
- [x] [parallel] Add focused package and module evaluation checks that instantiate the production package, Clan wrapper, generated Radicle config, interface-scoped firewall, private state directory, dedicated credential, and hardened node/HTTP services. r[onix.radicle_node.validation]

## Phase 2: Initial node deployment

- [x] [serial] Select `aspen1` as the bootstrap machine and preserve `root@aspen1.local` as its deployment target without treating mDNS as the public client endpoint. r[onix.radicle_node.hosting]
- [x] [serial] Assign Aspen1 the least-authority Radicle service with its recovered and fingerprint-pinned machine-scoped Clan identity, dedicated user, persistent state, selective seeding, local-only HTTP, and no access to delegate, CI, deployment, release, canonical-ref, cache, artifact, Buildbot, Nix-signing, Cloudflare, Vaultwarden, Matrix, or other co-hosted credentials. r[onix.radicle_node.hosting]
- [ ] [serial] Deploy the node endpoint and read-only `radicle-httpd` behind the reviewed HTTPS proxy while keeping undeclared listeners and repositories inaccessible. r[onix.radicle_node.exposure]
- [ ] [parallel] Verify service health, monitoring, restart continuity, exact-object native peer acquisition, and exact-object HTTPS Git acquisition from an independent client. r[onix.radicle_node.validation]
- [ ] [parallel] Verify unauthorized repository enumeration, private repository admission, writable HTTP operations, wildcard exposure, delegate-key access, and CI-key access fail closed. r[onix.radicle_node.exposure]

## Phase 3: Persistence and prerequisite evidence

- [ ] [serial] Back up the complete declared Radicle storage and node identity to a target outside Aspen1's failure domain under bounded retention, emit a BLAKE3 manifest, and restore it into a clean root or replacement service. r[onix.radicle_node.recovery]
- [ ] [parallel] Compare node ID, repository IDs, exact Git objects, signed refs, issues, patches, identities, and declared custom COB refs after restore; reject incomplete, tampered, permission-unsafe, or identity-changing backups. r[onix.radicle_node.recovery]
- [ ] [serial] Emit the redaction-safe bootstrap receipt and document startup, monitoring, backup, restore, incident, rollback, package upgrade, and key-loss procedures with explicit single-node and confidentiality non-claims. r[onix.radicle_node.bootstrap]
- [ ] [serial] Run focused Nickel, Nix module, selected-machine, service, Cairn, and flake validation; sync and archive only after downstream consumers can verify the bootstrap receipt. r[onix.radicle_node.bootstrap]
