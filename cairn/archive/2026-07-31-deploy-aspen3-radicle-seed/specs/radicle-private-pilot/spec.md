## MODIFIED Requirements

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
