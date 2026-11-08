# Saved-machine Gateway Deployment

## ADDED Requirements

### Requirement: Requested gateway source
r[onix.herdr_gateway.pin] britton-desktop MUST run herdr-iroh from commit `1ee15bf8506a13394de2f253ee6fd8febfca1a64` with its saved-machine gateway enabled and existing peer authorization preserved.

#### Scenario: Gateway source is deployed
- **GIVEN** the approved gateway pin and the existing relay authorization
- **WHEN** the requested release is activated
- **THEN** the running relay executable MUST match the package built from that exact source revision.

### Requirement: Compatible gateway executables
r[onix.herdr_gateway.path] The serve service MUST use Herdr 0.9.1 or newer and have Herdr and SSH available through the upstream herdrPackage configuration and service PATH.

#### Scenario: The gateway invokes its tools
- **GIVEN** the upstream herdrPackage option selects the compatible CLI
- **WHEN** the service forwards a saved-machine request
- **THEN** its configured herdr_bin MUST select the intended compatible CLI and ssh MUST resolve from the service PATH.

### Requirement: Publish and deploy the release
r[onix.herdr_gateway.release] The operator MUST build, commit, and push the scoped onix-core release before invoking Clan's machine update for britton-desktop, without bundling unrelated primary-worktree changes.

#### Scenario: Publication precedes activation
- **GIVEN** a scoped gateway release built against the preserved deployed baseline
- **WHEN** Clan updates britton-desktop
- **THEN** the requested gateway code MUST already be published, and the preserved deployed baseline and exact activation scope MUST have been reviewed.

### Requirement: Restart the relay executable
r[onix.herdr_gateway.restart] A new gateway binary MUST be activated by restarting the herdr-iroh serve process; SIGHUP alone MUST NOT be accepted as executable replacement.

#### Scenario: Process replacement is verified
- **GIVEN** the new gateway executable has been built without replacing Herdr
- **WHEN** deployment completes
- **THEN** relay PID/start/executable evidence MUST establish that it executes the new binary while preserving the service-owned endpoint identity.

### Requirement: Preserve the running Herdr server
r[onix.herdr_gateway.preservation] The operator MUST NOT stop, restart, hand off, or replace the running Herdr server or interrupt its agents. If the package update would force that, the operator MUST stop and report instead of activating or suppressing the safety condition.

#### Scenario: An unsafe restart is planned
- **GIVEN** the existing Herdr server and its agents are running
- **WHEN** preview requires a Herdr-server replacement
- **THEN** deployment MUST NOT proceed and the operator MUST report the concrete blocker.

### Requirement: Run the requested probe once
r[onix.herdr_gateway.probe] After deployment the operator MUST execute `herdr --machine instant-fill status server` exactly once and report its actual result and deployed versions.

#### Scenario: Probe result is available
- **GIVEN** deployment completed and the requested probe has not previously run
- **WHEN** that invocation returns
- **THEN** its exit status and stdout/stderr MUST be reported without concealing failure or retrying the command.

### Requirement: Leave webhook notifications unset
r[onix.herdr_gateway.notify] The deployed server configuration MUST leave the `[notify]` webhook section unset; this rollout MUST NOT configure a webhook endpoint or credential.

#### Scenario: The server configuration is rendered
- **GIVEN** notifications have not been configured for this rollout
- **WHEN** this gateway release is built and deployed
- **THEN** no notify webhook section or endpoint MUST be added to server.toml.

