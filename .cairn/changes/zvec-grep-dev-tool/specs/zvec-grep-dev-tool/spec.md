# zvec-grep Dev Tool

## ADDED Requirements

### Requirement: zvec-grep is packaged and pinned

r[onix.zvec_grep.packaging] Onix dev tooling MUST package `@zvec/zvec-grep` at revision `309a66995809243d3274fa8b5bea63ab11dda1a0` with Node 22. The packaged tool MUST run from a dev shell without network access to the npm registry.

#### Scenario: Packaged tool runs offline

r[onix.zvec_grep.packaging.offline]
- GIVEN the zg package is built into Onix dev tooling with Node 22
- WHEN the dev shell runs `zg query --rg -F "AuthService"`
- THEN zg MUST respond from the local package
- AND no npm network fetch MUST be required.

#### Scenario: Pinned revision is recorded

r[onix.zvec_grep.packaging.revision]
- GIVEN a maintainer builds the zg package
- WHEN the package references are checked
- THEN the recorded revision MUST equal `309a66995809243d3274fa8b5bea63ab11dda1a0`
- AND the Apache-2.0 notice MUST be present.

### Requirement: Configuration is typed and validated

r[onix.zvec_grep.config] zg workspace configuration MUST be authored as typed Nickel data with workspace roots, exclusions, model selection, and local or remote embedding mode. Runtime inputs MUST export to the tool-native format.

#### Scenario: Configuration validates

r[onix.zvec_grep.config.valid]
- GIVEN a typed zg configuration supplies workspace roots, exclusions, and an embedding mode
- WHEN configuration validation runs
- THEN the configuration MUST typecheck
- AND its exported inputs MUST satisfy the tool contract.

#### Scenario: Configuration is malformed

r[onix.zvec_grep.config.malformed]
- GIVEN a zg configuration omits a workspace root or declares an unknown embedding mode
- WHEN configuration validation runs
- THEN validation MUST fail.

### Requirement: Exact search works without an index

r[onix.zvec_grep.exact] A positional or `--rg` query MUST work without an index and without an embedding model.

#### Scenario: Exact query runs without an index

r[onix.zvec_grep.exact.noindex]
- GIVEN a workspace has no zg index
- WHEN a user runs an exact text or regex query
- THEN zg MUST return source-linked matches.

### Requirement: Agent access is loopback and bearer-protected

r[onix.zvec_grep.agent] Where the environment supports it, the zg MCP endpoint MUST bind loopback only and MUST require bearer authentication for local agents.

#### Scenario: Endpoint binds loopback

r[onix.zvec_grep.agent.loopback]
- GIVEN the zg server starts
- WHEN its listen address is inspected from a non-loopback interface
- THEN the service MUST NOT be reachable on that interface.

#### Scenario: Unauthenticated agent is denied

r[onix.zvec_grep.agent.auth]
- GIVEN an agent calls the MCP endpoint without a bearer token
- WHEN the server handles the request
- THEN the server MUST deny access.

### Requirement: Data stays local by default

r[onix.zvec_grep.privacy] zg MUST keep indexes and local embeddings on the machine. Remote embedding MUST send workspace or query content off the machine only with explicit workspace authorization.

#### Scenario: Remote embedding is denied without a grant

r[onix.zvec_grep.privacy.remote]
- GIVEN a workspace selects a remote embedding provider without an explicit grant
- WHEN an indexed query needs embedding
- THEN zg MUST NOT send the content off the machine.

### Requirement: Reference revision is recorded

r[onix.zvec_grep.reference] Repository references MUST record the zvec-grep revision `309a66995809243d3274fa8b5bea63ab11dda1a0`, version v0.2.1, project `github.com/zvec-ai/zvec-grep`, and the Apache-2.0 license.

#### Scenario: Reference is present

r[onix.zvec_grep.reference.record]
- GIVEN a maintainer inspects repository references
- WHEN the zvec-grep entry is read
- THEN the revision, version, project, and license MUST be present.

### Requirement: zvec-grep adoption has positive and negative verification

r[onix.zvec_grep.verification] The focused rail MUST cover offline packaging, exact no-index queries, configuration admission, loopback binding, bearer denial, and remote-embedding denial without a grant.

#### Scenario: Dev-tool rail passes

r[onix.zvec_grep.verification.rail]
- GIVEN the packaged tool, typed configuration, and focused fixtures are present
- WHEN the focused rail runs
- THEN positive checks MUST pass
- AND negative checks MUST fail without panic or hidden network use.
