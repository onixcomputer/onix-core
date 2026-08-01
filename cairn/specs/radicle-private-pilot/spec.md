# Radicle Private Pilot Specification

## Purpose

Defines the `radicle-private-pilot` capability.

## Requirements

### Requirement: Private repository publication is identity-bound

r[onix.radicle_private_pilot.publication] The private pilot MUST bind the non-secret fixture to an exact identity revision that authorizes every reviewed private seed.

#### Scenario: Aspen3 seed authorization is accepted

r[onix.radicle_private_pilot.publication.scenario.private]
- GIVEN the accepted Aspen1 and desktop peers and the fingerprint-pinned `aspen3` node DID
- WHEN the sole delegate accepts a new private identity revision
- THEN the privacy set MUST contain all three seed DIDs and the authorized client DID
- AND the denied client DID MUST remain absent

### Requirement: Native private admission remains separate from public exposure

r[onix.radicle_private_pilot.admission] Each reviewed native seed MUST seed the exact private pilot RID without adding it to explorer, HTTPS, or CI policy.

#### Scenario: Aspen3 private admission remains native-only

r[onix.radicle_private_pilot.admission.scenario.fail_closed]
- GIVEN `aspen3` is present in the accepted private identity privacy set
- WHEN its exact native policy reconciles
- THEN the private RID MUST be stored on `aspen3`
- AND no `radicle-httpd` unit or private HTTPS route MUST exist on `aspen3`

### Requirement: Each independent seed replicates the exact private object

r[onix.radicle_private_pilot.replication] Each reviewed seed MUST store the accepted private identity revision, delegate signed refs, canonical branch, reviewed commit, and source identity.

#### Scenario: Three-seed identity convergence is checked

r[onix.radicle_private_pilot.replication.scenario.exact]
- GIVEN Aspen1, `britton-desktop`, and `aspen3` store the private RID
- WHEN their canonical identity and delegate signed refs are compared
- THEN all three values MUST equal the accepted revision
- AND any RID, identity, signed-ref, commit, source-hash, or policy-count mismatch MUST fail acceptance

### Requirement: Private acquisition is limited to identity-authorized peers
r[onix.radicle_private_pilot.confidentiality] Fresh directly connected authorized clients MUST acquire the exact object from either seed, while a fresh peer absent from the identity privacy set MUST NOT observe the RID in tested seed inventory or acquire a checkout.

#### Scenario: Authorized direct acquisition succeeds
r[onix.radicle_private_pilot.confidentiality.scenario.authorized]
- GIVEN a fresh client identity present in the private allow set
- WHEN it connects directly to exactly one reviewed seed and clones with signed-reference feature `parent`
- THEN it SHALL reproduce the reviewed Git object and source BLAKE3

#### Scenario: Unauthorized direct acquisition fails
r[onix.radicle_private_pilot.confidentiality.scenario.denied]
- GIVEN a fresh client identity absent from delegates and the private allow set
- WHEN it queries seed inventory and attempts a direct clone
- THEN the private RID SHALL be absent from inventory, acquisition SHALL fail at the protocol boundary, and no checkout SHALL exist

### Requirement: Public HTTPS excludes the private repository
r[onix.radicle_private_pilot.https_exclusion] Public Nginx admission MUST remain generated from only the exact public repository set.

#### Scenario: Private routes remain absent
r[onix.radicle_private_pilot.https_exclusion.scenario.default_deny]
- GIVEN healthy public Git upload-pack service
- WHEN private upload-pack or receive-pack routes are requested
- THEN both private routes SHALL return `404` without weakening the public route

### Requirement: Encrypted backup and clean recovery preserve private state
r[onix.radicle_private_pilot.recovery] A post-publication encrypted archive MUST leave the primary failure domain, and a bounded clean-root restore MUST reproduce complete manifests, node identity, the private reviewed object, and source BLAKE3 before cleanup.

#### Scenario: Restore drift fails closed
r[onix.radicle_private_pilot.recovery.scenario.exact]
- GIVEN the accepted encrypted archive
- WHEN clean-root recovery or semantic private-object verification differs or plaintext staging survives cleanup
- THEN recovery acceptance SHALL fail

### Requirement: Private pilot evidence is typed and bounded
r[onix.radicle_private_pilot.evidence] The repository MUST export deterministic typed JSON and BLAKE3 evidence binding publication, policy, deployment, positive and negative probes, HTTPS exclusion, backup, recovery, authority boundaries, and explicit non-claims.

#### Scenario: Accepted evidence is deterministic
r[onix.radicle_private_pilot.evidence.scenario.accepted]
- GIVEN all live probes and deterministic validations succeed
- WHEN the receipt is exported twice
- THEN bytes and BLAKE3 SHALL agree and unsafe receipt mutations SHALL be rejected
