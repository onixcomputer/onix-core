# Campaign source admission

## ADDED Requirements

### Requirement: Exact declared source scope

r[onix.campaign_source.policy]

The forge MUST add only Campaign RID `rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN` to the existing public source set.
Aspen1, desktop, Aspen3, and HTTPS MUST derive the same set. Private, CI, and signed-reference policies MUST remain unchanged.

#### Scenario: Campaign admission

GIVEN the existing source list and Campaign RID
WHEN the inventory evaluates
THEN all declared public sets contain exactly the existing sources and Campaign.

#### Scenario: Crossed or expanded scope

GIVEN a duplicate, missing, unknown, private, or CI-crossed repository assignment
WHEN the admission check evaluates the assignment
THEN the check rejects it.

### Requirement: Preserve unrelated deployment state

r[onix.campaign_source.deployment]

The operator MUST use the reviewed deployment path and preserve unrelated live services, credentials, and node identities.
A failed existing policy gate or unsafe host difference MUST block deployment.

#### Scenario: Safe deployment

GIVEN passing policy checks and a candidate that preserves unrelated host state
WHEN the operator deploys the change
THEN the service-owned reconciler applies the declared source set.

#### Scenario: Unsafe host difference

GIVEN a candidate that omits an unrelated live service or a failed existing policy gate
WHEN the operator evaluates deployment readiness
THEN deployment remains blocked and the current system remains active.

### Requirement: Exact public source evidence

r[onix.campaign_source.acquisition]

Acceptance MUST bind fresh source acquisition to revision `e23e3edf1dc6a8c612a4ea33a3b805bda1173e3b` and its BLAKE3 archive identity.
Acceptance MUST record native replication and HTTPS rejection probes separately from policy checks.

#### Scenario: Exact acquisition

GIVEN deployed source policy and the published revision
WHEN a fresh HTTPS checkout retrieves that revision
THEN Git object validation and the BLAKE3 archive comparison pass.

#### Scenario: Unavailable or unsafe source route

GIVEN a missing revision, changed archive, accepted write route, or accepted undeclared repository
WHEN the operator evaluates acquisition evidence
THEN acceptance remains blocked without a release or consumer-readiness claim.
