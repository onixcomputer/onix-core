## ADDED Requirements

### Requirement: Pinned upstream package

r[onix.underclass.source] Underclass MUST come from a locked `ghuntley/underclass` flake input. Adding it MUST NOT advance existing input revisions.

#### Scenario: Reproducible package

- GIVEN the repository lock
- WHEN the exported `underclass` package is built
- THEN the upstream CLI and `utop` MUST be available from the locked source

### Requirement: OMP machine scope

r[onix.underclass.scope] The OMP provider MUST be enabled on `britton-desktop` and `aspen3` only, through the existing `omp-agents` instance. The Underclass service MUST run only on `britton-desktop`; `aspen3` MUST reach that pool through a loopback SSH tunnel instead of running a second pool.

#### Scenario: Unselected client

- GIVEN another `llm-client` machine such as `aspen1`
- WHEN its configuration is evaluated
- THEN Underclass MUST remain disabled

#### Scenario: Shared-pool client

- GIVEN `aspen3` with `ompUnderclassRemoteHost = "britton-desktop"`
- WHEN its configuration is evaluated
- THEN it MUST install the OMP provider and the SSH tunnel user service
- AND it MUST NOT enable the Underclass service or generate Underclass credentials

### Requirement: Local persistent service

r[onix.underclass.local-service] Underclass MUST bind to `127.0.0.1:8080`, leave the firewall closed, retain its pool in persistent dynamic-user state, and disable automatic banked Codex reset redemption.

#### Scenario: Private listener

- GIVEN an enabled workstation
- WHEN Underclass starts
- THEN it MUST require authentication for model and admin APIs
- AND it MUST NOT expose a non-loopback listener

### Requirement: Runtime credentials

r[onix.underclass.secrets] Clan vars MUST generate independent proxy and admin keys for each machine that runs the service. The managed OMP user MUST be able to read its own keys; a shared-pool client MUST read the serving machine's proxy key over SSH at request time. The service environment file MUST be root-only, and no key or upstream OAuth credential MUST be embedded in the Nix store or repository plaintext.

#### Scenario: OAuth ownership

- GIVEN an existing OMP login
- WHEN Underclass is enabled
- THEN the login MUST remain unchanged
- AND Underclass accounts MUST be enrolled separately through upstream device authorization

### Requirement: Native additive OMP provider

r[onix.underclass.omp] OMP MUST expose Underclass models through its authenticated loopback Responses API without overwriting existing providers, credentials, defaults or research extensions. Requests MUST carry the session prompt-cache key needed for account affinity and MUST use a request shape accepted by the subscription backend.

#### Scenario: Select pooled inference

- GIVEN the managed extension and a configured proxy key
- WHEN OMP selects `underclass/gpt-6-astra`
- THEN it MUST send an authenticated Responses request to the local Underclass service
- AND an empty pool MUST return its real unavailable-pool error rather than silently falling back to a direct provider

### Requirement: Observed verification

r[onix.underclass.verification] Verification MUST include the built proxy and native OMP runtime, selected and unselected configuration evaluations, and explicit account-enrollment/deployment limits. It MUST NOT claim successful upstream inference without an enrolled account and an observed response.

#### Scenario: Empty-pool verification

- GIVEN a fresh isolated pool without upstream accounts
- WHEN API authentication, discovery and an OMP request are exercised
- THEN unauthorized requests MUST fail authentication
- AND authorized model discovery MUST succeed
- AND the OMP request MUST reach Underclass and report the actual empty-pool failure
