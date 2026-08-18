# Radicle Replica Specification

## ADDED Requirements

### Requirement: Personal desktop node is supervised
r[onix.radicle_replica.personal_supervision] `britton-desktop` MUST supervise the personal Radicle node through the managed user service without transferring machine-scoped replica authority.

The service MUST preserve `/home/brittonr/.radicle`, the personal control socket, and the personal identity. It MUST NOT use `/var/lib/radicle` or machine-scoped credentials.

#### Scenario: Personal node starts with the user manager
r[onix.radicle_replica.personal_supervision.start]
- GIVEN the desktop Home Manager profile and personal Radicle state
- WHEN the user manager reaches its default target
- THEN `radicle-personal-node.service` starts through the reviewed desktop wrapper
- AND the service uses the personal home and control socket

#### Scenario: External termination restarts the node
r[onix.radicle_replica.personal_supervision.restart]
- GIVEN the personal node is active under the user manager
- WHEN the node exits after an external termination signal
- THEN systemd restarts it after the declared delay
- AND an explicit user stop remains stopped

### Requirement: Personal supervision survives session boundaries
r[onix.radicle_replica.personal_persistence] `britton-desktop` MUST enable lingering for the managed user that owns the personal Radicle node.

#### Scenario: User manager persists without a login session
r[onix.radicle_replica.personal_persistence.linger]
- GIVEN the desktop system configuration is active
- WHEN the interactive session logs out or the host boots
- THEN the user manager remains available to supervise the personal node

### Requirement: Personal node preserves listener isolation
r[onix.radicle_replica.personal_listener] The supervised personal node MUST use an operating-system-selected loopback port.

The desktop user slice MUST reject TCP port `8776`. The service MUST reject an explicit listener override.

#### Scenario: Managed and personal listeners remain separate
r[onix.radicle_replica.personal_listener.separate]
- GIVEN the machine-scoped replica and personal node run on `britton-desktop`
- WHEN both listeners are inspected
- THEN the replica owns its reviewed tailnet listener
- AND the personal node owns only an ephemeral loopback listener

#### Scenario: Managed port claim is rejected
r[onix.radicle_replica.personal_listener.rejected]
- GIVEN a process in the desktop user slice
- WHEN it tries to bind TCP port `8776`
- THEN the kernel bind filter rejects the request

### Requirement: Personal node uses user signing authority
r[onix.radicle_replica.personal_signer] The personal service MUST use the user YubiKey agent socket without copying its key into system credentials.

#### Scenario: User signer is selected
r[onix.radicle_replica.personal_signer.socket]
- GIVEN the YubiKey agent service and user runtime directory
- WHEN the personal node starts
- THEN its SSH agent socket resolves below the user runtime directory
- AND no numeric user ID is embedded in the unit

### Requirement: Personal supervision has positive and negative checks
r[onix.radicle_replica.personal_validation] Focused validation MUST inspect service startup, restart policy, listener isolation, user persistence, and host scope.

#### Scenario: Desktop service shape passes
r[onix.radicle_replica.personal_validation.positive]
- GIVEN the evaluated `britton-desktop` configuration
- WHEN focused Home Manager and system checks run
- THEN the service, package, socket, listener, signer order, restart policy, bind guard, and linger setting match policy

#### Scenario: Other profiles exclude the service
r[onix.radicle_replica.personal_validation.negative]
- GIVEN the managed laptop and server Home Manager profiles
- WHEN focused Home Manager checks run
- THEN neither profile contains `radicle-personal-node.service`
