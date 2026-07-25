# Radicle Ci Specification

## Purpose

Defines the `radicle-ci` capability.

## Requirements

### Requirement: Typed CI deployment configuration r[onix.radicle_ci.configuration]

Onix Core MUST lower a typed configuration that fixes the host, admitted RID,
production seed, signed-reference feature, bot identity, job command, resource
limits, lock identities, artifact/status locations, and monitoring policy.

#### Scenario: Exact pilot policy is accepted

- **GIVEN** Aspen1, the admitted public RID, feature `parent`, bounded limits, and one pinned production seed
- **WHEN** the CI deployment configuration is validated
- **THEN** deterministic bot, scanner, runner, publisher, and monitoring settings are produced

#### Scenario: Expanded authority is rejected

- **GIVEN** a different RID, delegate identity, external listener, unbounded limit, credential-bearing job, shared-cache write, deployment effect, or production seed-policy mutation
- **WHEN** the configuration is validated
- **THEN** deployment is rejected before a service can start

### Requirement: Exact-object admission and durable deduplication r[onix.radicle_ci.admission]

The scanner MUST admit only current canonical or open-patch objects for the
configured RID, preserve exact patch/revision/object linkage, reject changed
lock identities, and derive a stable BLAKE3 job identity that survives restart.

#### Scenario: Current patch revision is admitted once

- **GIVEN** a current open patch revision with the expected locks and exact local object
- **WHEN** repeated scans run before and after service restart
- **THEN** one immutable event/archive pair and one job identity are produced

#### Scenario: Stale or altered source is rejected

- **GIVEN** a stale revision, missing object, wrong RID, malformed ref, changed lockfile, or mismatched archive
- **WHEN** admission runs
- **THEN** no runnable job is produced and a stable rejection diagnostic is recorded

### Requirement: Bounded isolated execution r[onix.radicle_ci.execution]

The runner MUST execute the accepted Nix command through `bounded-exec` with
explicit argv/environment/cwd/stdin/output/deadline/teardown limits, no network,
no credentials, and an isolated local Nix store.

#### Scenario: Admitted source completes

- **GIVEN** an admitted immutable event/archive pair and locally available locked flake inputs
- **WHEN** the runner executes the configured check
- **THEN** it emits bounded stdout/stderr identities, disposition, artifact identity, and claim-scoped status facts

#### Scenario: Execution exceeds a boundary

- **GIVEN** timeout, cancellation, output flood, non-zero exit, malformed output, artifact failure, or unavailable offline input
- **WHEN** the runner executes
- **THEN** owned processes are torn down and the exact bounded failure remains publishable without claim escalation

### Requirement: Bot and runner authority separation r[onix.radicle_ci.isolation]

The CI bot and runner MUST use separate users and state roots. The bot MAY own a
non-delegate machine identity and its own node/status namespace. The runner MUST
lack every Radicle key/socket/profile, production seed state/socket, deployment
secret, cache-signing key, user home, and network path.

#### Scenario: Runner is inspected

- **GIVEN** the deployed runner service
- **WHEN** unit properties, mount visibility, credentials, sockets, capabilities, address families, and writable paths are inspected
- **THEN** only its exchange, local store, work, artifact, and result paths are available

#### Scenario: Bot attempts canonical authority

- **GIVEN** the bot DID is not a delegate
- **WHEN** it writes a patch status under its own namespace
- **THEN** the comment can replicate without granting canonical branch, identity, tag, merge, release, deployment, cache-write, or production seed-policy authority

### Requirement: Positive and negative deployment validation r[onix.radicle_ci.validation]

The repository MUST keep positive and negative tests for package behavior,
configuration, exact object admission, authority separation, resource limits,
status retry, and restart deduplication.

#### Scenario: Focused validation runs

- **GIVEN** the package, module, inventory, and receipt source
- **WHEN** focused Cargo, Nickel, Nix, machine-build, and Cairn checks run
- **THEN** accepted cases pass and malformed, stale, over-authoritative, and over-limit cases fail closed

### Requirement: Non-delegate bot identity r[onix.radicle_ci.identity]

The bot identity MUST be generated through encrypted Clan variables, verify its
private/public pairing and pinned fingerprint before node start, and differ from
all project delegates and production seed identities.

#### Scenario: Identity prerequisite succeeds

- **GIVEN** the encrypted bot key and pinned public fingerprint
- **WHEN** the identity prerequisite runs
- **THEN** key pairing, fingerprint, bot node ID, non-delegate status, and state ownership are verified

#### Scenario: Identity material drifts

- **GIVEN** a mismatched key pair, changed fingerprint, delegate DID, seed node ID, missing file, or permissive mode
- **WHEN** the prerequisite runs
- **THEN** the bot node and dependent CI services do not start

### Requirement: Aspen1 CI deployment r[onix.radicle_ci.deployment]

Onix Core MUST build and deploy the complete CI closure to Aspen1 without
changing the production seed identity, exact seeding policy, public HTTP route,
canonical RID, or reviewed source object.

#### Scenario: Deployment survives restart

- **GIVEN** a successful Aspen1 deployment
- **WHEN** bot, scanner, runner, publisher, and host services restart
- **THEN** identities, queues, deduplication, monitoring, exact-RID policy, and existing forge endpoints remain accepted

### Requirement: Real patch and adversarial drill r[onix.radicle_ci.drill]

Acceptance MUST include a real patch authored outside the bot profile, native
replication to the bot, exact-object bounded execution, a bot status comment,
and negative attempts to obtain forbidden authority.

#### Scenario: Patch job is observed end to end

- **GIVEN** a non-canonical patch with unchanged locks
- **WHEN** it is announced to Aspen and fetched by the bot
- **THEN** one job runs for its exact head and the matching BLAKE3-bound status appears on its exact revision

#### Scenario: Patch requests forbidden effects

- **GIVEN** source or event facts requesting credentials, network, lock updates, cache writes, deployment, canonical mutation, or seed-policy mutation
- **WHEN** admission or execution runs
- **THEN** the request is rejected and production seed/canonical refs remain unchanged

### Requirement: Bounded deployment evidence r[onix.radicle_ci.evidence]

The deployment MUST emit a typed BLAKE3-bound receipt linking policy, package,
machine closure, bot identity, exact patch/object, job/artifact/status, restart,
isolation, rejection probes, monitoring, and explicit non-claims.

#### Scenario: Receipt is accepted

- **GIVEN** completed deployment and drills
- **WHEN** repository and downstream validators evaluate the receipt
- **THEN** exact evidence links pass without asserting source correctness, host sandboxing, artifact durability, mandatory merge enforcement, private confidentiality, automatic failover, or release readiness
