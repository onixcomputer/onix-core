# Radicle CI Delta Specification

## MODIFIED Requirements

### Requirement: Signed machine-readable status

r[onix.radicle_ci.canonical_guard.status] The non-delegate CI publisher MUST place a closed machine-readable status payload in its signed exact-revision patch comment, binding the accepted policy, RID, patch/revision, check name, job/object, disposition, artifact, event/result identities, and bounded non-claim. Its protocol marker MUST survive the deployed Radicle CLI comment sanitizer unchanged.

#### Scenario: Exact successful status is published

- GIVEN an admitted patch event and matching successful result
- WHEN the publisher renders and submits the status through the deployed Radicle CLI
- THEN the stored comment MUST begin with the exact visible protocol marker
- AND the closed JSON payload and human non-claim MUST remain parseable

#### Scenario: Sanitized or malformed status is rejected

- GIVEN an HTML-editor marker, malformed JSON, unknown field, wrong identity, failed disposition, wrong author, or weakened non-claim
- WHEN publication or guard materialization runs
- THEN publication MUST fail visibly or the stored status MUST NOT contribute to canonical admission
- AND no canonical ref may change
