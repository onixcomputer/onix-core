## Phase 1: Private fixture and policy split

- [x] [serial] P1 Publish the non-secret fixture with private visibility, exact allowed peers, frozen Git/source/identity facts, and an explicit denied identity. r[onix.radicle_private_pilot.publication]
- [x] [depends:P1] I1 Split exact public and private native seed settings while preserving the existing HTTPS and CI scopes. r[onix.radicle_private_pilot.admission]
- [x] [depends:I1] V1 Add positive and negative module fixtures for exact admission, malformed or duplicate RIDs, overlap, and HTTPS exclusion. r[onix.radicle_private_pilot.admission.scenario.fail_closed]

## Phase 2: Deployment and confidentiality probes

- [x] [depends:V1] I2 Build and deploy both reviewed host closures, reconcile exactly four native policies, and verify the private identity/object refs on each seed. r[onix.radicle_private_pilot.replication]
- [x] [depends:I2] V2 Prove independent fresh authorized acquisition from each seed and fresh unauthorized inventory non-disclosure and acquisition rejection. r[onix.radicle_private_pilot.confidentiality]
- [x] [depends:I2] V3 Prove private HTTPS upload-pack and receive-pack remain absent while public upload-pack remains healthy. r[onix.radicle_private_pilot.https_exclusion]

## Phase 3: Durability and evidence

- [x] [depends:V2] [depends:V3] V4 Complete encrypted backup and clean-root recovery with a semantic private-object probe. r[onix.radicle_private_pilot.recovery]
- [x] [depends:V4] D1 Export typed JSON/BLAKE3 evidence and document operations, rollback, authority boundaries, and non-claims. r[onix.radicle_private_pilot.evidence]
- [ ] [depends:D1] V5 Run focused checks, host builds, repository validation, Cairn gates, sync the accepted specification, and archive the completed change. r[onix.radicle_private_pilot.evidence.scenario.accepted]

Blocked: the branch currently contains staged execution-graph public admission whose producer delegate quorum is incomplete. Do not sync, archive, merge, or push this change until that source is accepted or removed. The broad flake rail also remains bounded by an active aarch64 QEMU `nix-wasm-plugins` build after 30 minutes; focused checks and both x86_64 host builds pass.
