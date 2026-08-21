## ADDED Requirements

### Requirement: Deployment consumes the accepted portable contract

r[onix.radicle_source_browser.contract] `onix-core` MUST deploy only a browser configuration that matches the accepted OnixOS contract, policy identity, RID set, routes, limits, and non-claims.

#### Scenario: Accepted contract is present

- GIVEN the OnixOS browser contract is accepted and matches the deployment inputs
- WHEN deployment planning runs
- THEN the plan MUST bind the exact contract and policy identities

#### Scenario: Contract is absent or stale

- GIVEN the contract is missing, unaccepted, changed, or inconsistent with local configuration
- WHEN deployment planning runs
- THEN deployment MUST stop before package, source, generation, proxy, or publication effects

### Requirement: Renderer selection is licensed and bounded

r[onix.radicle_source_browser.component_selection] The deployment MUST use an independently licensed renderer whose reviewed capabilities satisfy every accepted view, object, output, and resource requirement.

#### Scenario: Published component satisfies the contract

- GIVEN a component has an immutable source revision, compatible license, bounded adapter, and complete capability matrix
- WHEN component admission runs
- THEN the deployment MAY select its exact package and executable identities

#### Scenario: Radiant Forge material is copied

- GIVEN implementation source, templates, assets, or tests derive from the all-rights-reserved Radiant Forge project
- WHEN provenance and license review runs
- THEN selection MUST fail before packaging or deployment

#### Scenario: Renderer lacks one required bound

- GIVEN a renderer or wrapper cannot enforce one declared route or resource limit
- WHEN component admission runs
- THEN selection MUST fail with the unsupported capability

### Requirement: Source observation has no governance authority

r[onix.radicle_source_browser.source_boundary] Generation MUST read one explicit admitted public RID and exact tagged Git object through read-only local authority.

#### Scenario: Exact public source is selected

- GIVEN one admitted public RID contains the requested exact object in local Radicle storage
- WHEN generation starts
- THEN the shell MAY create one separate bounded read-only materialization
- AND the renderer MUST receive no repository mutation or governance capability

#### Scenario: Source selection is unsafe

- GIVEN the RID is unknown or private, the object is missing, the source changed, or the request uses an ambient scan
- WHEN source admission runs
- THEN generation MUST fail before renderer execution

### Requirement: Snapshot generation is bounded

r[onix.radicle_source_browser.generation] Each generation MUST run under explicit Bounded Exec limits and MUST admit its output through Bounded Tree before publication.

#### Scenario: Valid snapshot is generated

- GIVEN source, renderer, route, and limit identities are admitted
- WHEN bounded generation completes
- THEN output-tree admission MUST validate paths, types, members, depth, file sizes, total bytes, and the complete manifest

#### Scenario: Generator or tree exceeds policy

- GIVEN the renderer times out, signals, truncates output, or creates unsafe or over-limit output
- WHEN generation or tree admission runs
- THEN no snapshot or current pointer MUST be published

### Requirement: Publication is immutable and pointer-last

r[onix.radicle_source_browser.publication] The deployment MUST publish a complete immutable snapshot before it creates or replaces the current pointer.

#### Scenario: New snapshot becomes current

- GIVEN one complete admitted snapshot is absent from publication storage
- WHEN publication executes an accepted plan
- THEN the immutable snapshot MUST publish first
- AND the current pointer MUST bind its RID, Git object, manifest, policy, and receipt identities

#### Scenario: Publication plan is stale or interrupted

- GIVEN source, policy, output, prior pointer, or plan identity changed before commit
- WHEN publication executes
- THEN it MUST reject the stale plan
- AND the prior current pointer MUST remain valid

### Requirement: Public browser exposure remains default-deny

r[onix.radicle_source_browser.exposure] Nginx MUST serve only accepted browser prefixes, admitted RID paths, and immutable snapshot content. Existing upload-pack behavior MUST remain separate and unchanged.

#### Scenario: Admitted view is requested

- GIVEN one published snapshot and an accepted summary, refs, tree, blob, raw, commit, or diff route
- WHEN an HTTPS client requests the route
- THEN the gateway MUST return the bounded static response with required security headers

#### Scenario: Undeclared or writable route is requested

- GIVEN a client requests root enumeration, unknown RID, private source, receive-pack, mutation method, login, API, unsafe path, or undeclared route
- WHEN the request reaches the gateway
- THEN it MUST fail without exposing local paths, credentials, repository content, or mutation capability

### Requirement: Browser operations are explicit and recoverable

r[onix.radicle_source_browser.operations] The deployment MUST define monitoring, retention, rollback, cleanup, pointer recovery, and incident procedures for browser snapshots.

#### Scenario: Current snapshot is unhealthy

- GIVEN serving or integrity probes fail for the current snapshot
- WHEN an operator applies an accepted rollback plan
- THEN the pointer MUST select one earlier admitted snapshot
- AND immutable source and evidence records MUST remain available under retention policy

### Requirement: Browser evidence is redaction safe

r[onix.radicle_source_browser.evidence] Generation and deployment receipts MUST bind exact source, renderer, policy, limits, output, publication, route, probe, and rollback facts with explicit non-claims.

#### Scenario: Receipt verifies

- GIVEN accepted generation and deployment observations
- WHEN receipt validation runs
- THEN it MUST reproduce every identity and verdict without secrets, local paths, raw environments, or unbounded logs

#### Scenario: Receipt claims source correctness

- GIVEN a receipt claims rendered source is reviewed, correct, safe, confidential, available, or release eligible
- WHEN receipt validation runs
- THEN it MUST reject the overclaim
