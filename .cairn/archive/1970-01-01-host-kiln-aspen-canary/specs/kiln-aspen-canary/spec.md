# Kiln-on-Aspen Canary Specification Delta

## Purpose

Define the bounded private canary that composes Kiln semantics, Aspen hosting, and Lattice workflow execution without fallback.

## ADDED Requirements

### Requirement: Exact deployable dependency preflight

r[onix.kiln_aspen_canary.preflight] Onix Core MUST enable the canary only when immutable reviewed Aspen, Kiln, and Lattice revisions expose every required runtime binary and exact protocol contract.

#### Scenario: Complete dependency cohort is admitted

r[onix.kiln_aspen_canary.preflight.accepted]
- GIVEN the reviewed inputs expose the Kiln host bridge, Kiln extension, Aspen host contract, and Lattice workflow exchange
- WHEN the canary configuration is evaluated
- THEN the package and protocol identities MUST match the typed deployment profile
- AND no source MAY come from an ambient sibling worktree

#### Scenario: Library or fixture is presented as a service

r[onix.kiln_aspen_canary.preflight.rejected]
- GIVEN an input exposes only an Aspen library, `LocalAspenService`, test support, or a recording-only effect port
- WHEN the canary configuration is evaluated
- THEN enablement MUST fail before any service or socket is created

### Requirement: Separate explicit canary composition

r[onix.kiln_aspen_canary.composition] Onix Core MUST compose a separate Kiln host bridge, Aspen native host, and Lattice workflow exchange with explicit profiles, sockets, service ordering, and positive resource bounds.

#### Scenario: Operator submits the controlled canary

r[onix.kiln_aspen_canary.composition.accepted]
- GIVEN all three services use the reviewed profiles and the provider socket is ready
- WHEN the operator submits one controlled trigger to the Aspen canary socket
- THEN Aspen MUST execute the Kiln extension through its bounded native-process port
- AND Lattice MUST observe the exact routed workflow request
- AND the Lattice connection budget MUST cover one dispatch plus every admitted poll for each host request
- AND Kiln MUST record the exact terminal observation or `Unknown`

#### Scenario: Endpoint or profile is unavailable

r[onix.kiln_aspen_canary.composition.rejected]
- GIVEN a missing socket, wrong file type, changed profile identity, stale generation, malformed frame, or unavailable provider
- WHEN a canary request is considered
- THEN the request MUST fail closed without selecting another runtime or provider

### Requirement: Materialized provider completion

r[onix.kiln_aspen_canary.completion] Aspen and Kiln MUST preserve the exact bounded provider completion value through effect routing, callback delivery, and Kiln terminal classification.

#### Scenario: Lattice returns a terminal observation

r[onix.kiln_aspen_canary.completion.accepted]
- GIVEN Lattice returns a bounded observation whose bytes match its BLAKE3 identity
- WHEN Aspen admits the effect completion
- THEN Aspen MUST materialize the exact bytes for the Kiln callback
- AND Kiln MUST derive terminal meaning only from the admitted typed value

#### Scenario: Completion value is absent or changed

r[onix.kiln_aspen_canary.completion.rejected]
- GIVEN the completion bytes are missing, oversized, identity-mismatched, malformed, or semantically unsupported
- WHEN the callback handles the completion
- THEN Kiln MUST retain `Unknown` or reject the completion
- AND it MUST NOT infer success from a reference alone

### Requirement: Least-authority local service boundary

r[onix.kiln_aspen_canary.authority] The canary services MUST use separate users and state roots, grant only admitted Unix socket access, and deny ambient credentials, Radicle storage, and unrelated host paths.

#### Scenario: Evaluated service boundary is narrow

r[onix.kiln_aspen_canary.authority.accepted]
- GIVEN the enabled canary module
- WHEN its users, groups, sockets, paths, capabilities, address families, and service dependencies are inspected
- THEN each service MUST receive only its declared local capabilities
- AND the host bridge MUST have no Radicle or deployment credentials

#### Scenario: Authority expands beyond the profile

r[onix.kiln_aspen_canary.authority.rejected]
- GIVEN wildcard socket permissions, shared service state, network access, a credential path, or production Radicle storage access
- WHEN the module is evaluated
- THEN evaluation MUST fail or the focused authority check MUST reject the closure

### Requirement: Existing CI path and uncertainty remain intact

r[onix.kiln_aspen_canary.failure] The canary MUST remain separate from the current Seaglass broker route and MUST preserve disconnect-after-acceptance as `Unknown` without automatic fallback.

#### Scenario: Canary runs beside existing CI

r[onix.kiln_aspen_canary.failure.accepted]
- GIVEN the current Seaglass Kiln broker trigger and the enabled operator-only canary
- WHEN the machine configuration is evaluated
- THEN the existing broker command and trigger MUST remain unchanged
- AND no broker event MUST target the canary socket

#### Scenario: Canary loses acceptance certainty

r[onix.kiln_aspen_canary.failure.unknown]
- GIVEN a timeout or disconnect after Aspen may have accepted the operation
- WHEN the host bridge cannot prove a terminal result
- THEN Kiln MUST record `Unknown` and require reconciliation
- AND it MUST NOT retry through Lattice, the direct adapter, or another Aspen endpoint

### Requirement: Bounded private canary evidence

r[onix.kiln_aspen_canary.evidence] Onix Core MUST retain positive and negative configuration checks plus one operator-controlled live receipt before the canary can be called ready.

#### Scenario: Canary evidence is accepted

r[onix.kiln_aspen_canary.evidence.accepted]
- GIVEN the focused package, module, protocol, authority, and live drills pass
- WHEN the receipt is validated
- THEN it MUST bind the exact revisions, profiles, sockets, operation, provider observation, and terminal classification
- AND it MUST identify the claim as a private process-scoped canary

#### Scenario: Evidence overclaims deployment

r[onix.kiln_aspen_canary.evidence.rejected]
- GIVEN only builds, simulations, fixture harnesses, or process-local observations
- WHEN a receipt claims production availability, global durability, CI correctness, or release eligibility
- THEN validation MUST reject that claim
