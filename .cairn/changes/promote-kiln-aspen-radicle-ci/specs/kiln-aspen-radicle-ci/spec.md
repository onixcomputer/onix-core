# Kiln Aspen Radicle CI Production Specification Delta

## ADDED Requirements

### Requirement: Existing broker continuity during staging

r[onix.radicle_ci.aspen_continuity] Onix Core MUST keep the admitted Seaglass broker route executable during production staging by pinning its legacy direct Kiln executor separately from the Aspen host cohort.

#### Scenario: Legacy route runs during staging

r[onix.radicle_ci.aspen_continuity.accepted]
- GIVEN the broker still selects the legacy route before cutover
- WHEN one admitted Seaglass event starts its adapter
- THEN the adapter MUST use the immutable compatible executable and exact existing policy
- AND the Aspen host input MUST NOT change that command shape

#### Scenario: Incompatible Kiln CLI reaches the broker

r[onix.radicle_ci.aspen_continuity.rejected]
- GIVEN an executable requires profile or runtime arguments that the broker command does not supply
- WHEN the machine configuration is evaluated
- THEN the focused continuity gate MUST reject the closure before deployment

### Requirement: Separate production Aspen composition

r[onix.radicle_ci.aspen_composition] Onix Core MUST deploy a production Kiln Aspen host and exact Lattice workflow as a cohort separate from the operator canary, with immutable revisions, explicit profiles, distinct users, state roots, sockets, ordering, and finite resources.

#### Scenario: Production cohort starts

r[onix.radicle_ci.aspen_composition.accepted]
- GIVEN the reviewed durable host, provider, Aspen, Lattice, and Bounded Exec revisions
- WHEN the production services start
- THEN every profile and executable identity MUST match before either socket accepts work
- AND the host MUST route only the exact admitted Lattice provider effect

#### Scenario: Cohort or endpoint drifts

r[onix.radicle_ci.aspen_composition.rejected]
- GIVEN a changed revision, profile, executable, workflow, socket type, state root, generation, or non-positive bound
- WHEN evaluation or service admission runs
- THEN the production cohort MUST fail closed
- AND it MUST NOT select the canary, direct Lattice, or legacy executor

### Requirement: Least-authority production source boundary

r[onix.radicle_ci.aspen_authority] The production workflow MUST receive read access only to the admitted Seaglass repository view and write access only to its own state and report roots, without Radicle identity, node, policy, unrelated repository, home, secret, or network authority.

#### Scenario: Exact source view is available

r[onix.radicle_ci.aspen_authority.accepted]
- GIVEN one broker event names the admitted Seaglass RID and exact revision
- WHEN the Lattice provider starts
- THEN it MUST read that revision through the reviewed source view
- AND its user, mounts, groups, paths, sockets, and capabilities MUST expose no broader Radicle authority

#### Scenario: Source or authority escapes the profile

r[onix.radicle_ci.aspen_authority.rejected]
- GIVEN another RID, an escaping path, a Radicle key, node socket, policy database, wildcard mount, credential, home path, or network capability
- WHEN the production module is evaluated or probed
- THEN the closure or live probe MUST reject the expanded authority

### Requirement: Explicit broker cutover without fallback

r[onix.radicle_ci.aspen_cutover] After shadow gates and a drained broker boundary pass, Onix Core MUST invoke the Kiln adapter with explicit Defelo protocol and Aspen runtime arguments for the admitted Seaglass trigger.

#### Scenario: Broker event uses Aspen

r[onix.radicle_ci.aspen_cutover.accepted]
- GIVEN the production sockets are ready and no legacy adapter is active
- WHEN the broker starts one admitted event
- THEN its only adapter command MUST select `--protocol defelo --runtime aspen`
- AND the resulting effect MUST pass through Aspen and the exact Lattice workflow

#### Scenario: Aspen is unavailable after cutover

r[onix.radicle_ci.aspen_cutover.unavailable]
- GIVEN the selected Aspen endpoint, profile, host state, or provider is unavailable
- WHEN the broker starts an admitted event
- THEN the event MUST fail or remain unknown according to acceptance certainty
- AND it MUST NOT invoke the legacy adapter, direct Lattice, or canary automatically

### Requirement: Production operations and explicit rollback

r[onix.radicle_ci.aspen_operations] Onix Core MUST provide bounded status, alerts, backup/restore, upgrade, drain, and explicit rollback procedures that preserve operation certainty and source authority.

#### Scenario: Operator selects rollback

r[onix.radicle_ci.aspen_operations.accepted]
- GIVEN the broker is drained and no hosted operation remains unresolved
- WHEN the operator selects the immutable legacy route and redeploys or starts the reviewed rollback action
- THEN subsequent events MUST use only the legacy adapter
- AND the rollback MUST retain the Aspen evidence and state for reconciliation

#### Scenario: Rollback would duplicate uncertain work

r[onix.radicle_ci.aspen_operations.rejected]
- GIVEN an Aspen operation is pending or uncertain
- WHEN rollback admission runs
- THEN rollback MUST stop before a second execution path starts
- AND the operator MUST reconcile or explicitly retire the operation first

### Requirement: Bounded live production evidence

r[onix.radicle_ci.aspen_evidence] Onix Core MUST retain exact live evidence for broker input, hosted execution, report and status publication, failure, uncertainty, replay, restart, corruption, teardown, load, backup/restore, cutover, and rollback before archive.

#### Scenario: Production event completes

r[onix.radicle_ci.aspen_evidence.accepted]
- GIVEN a real private Seaglass default-branch event reaches the managed broker
- WHEN the production route completes
- THEN one broker event, Kiln run, Aspen operation, Lattice request, provider report, and Radicle status MUST bind the same exact revision and terminal result
- AND replay after service restart MUST not create a second provider dispatch

#### Scenario: Evidence is fixture-only or overclaims

r[onix.radicle_ci.aspen_evidence.rejected]
- GIVEN only direct commands, operator fixtures, service-active states, local hashes, or machine-local durability observations
- WHEN evidence claims broker cutover, CI correctness, global durability, exactly-once delivery, production availability, host sandboxing, external effect truth, or release eligibility
- THEN validation MUST reject the unsupported claim
