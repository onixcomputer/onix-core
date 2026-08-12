# Remote Builder Routing Delta

## ADDED Requirements

### Requirement: Remote builders use explicit reachable endpoints

r[onix.remote_builder.routing] The system MUST select a typed explicit SSH endpoint before a machine LAN address, MUST bind that endpoint to the managed host key, and MUST preserve the old fallback when no explicit endpoint exists.

#### Scenario: Aspen uses its reachable builder route

- GIVEN `britton-desktop` can reach Aspen through `aspen1.local`
- AND Aspen's cluster address is not routed from the desktop
- WHEN Nix evaluates the desktop builder list
- THEN the Aspen builder endpoint is `aspen1.local`
- AND the builder list does not contain `10.10.10.1`
- AND the managed Aspen host key includes `aspen1.local`

r[onix.remote_builder.routing.contract]
r[onix.remote_builder.routing.aspen]
r[onix.remote_builder.routing.selection]
r[onix.remote_builder.routing.host_key]

#### Scenario: A target omits an explicit endpoint

- GIVEN a valid builder target without `sshHost`
- WHEN the builder list is evaluated
- THEN selection uses its LAN address when present
- AND selection otherwise uses its machine name

#### Scenario: An empty endpoint is rejected

- GIVEN a builder target whose `sshHost` is empty
- WHEN the Nickel contract is evaluated
- THEN evaluation fails before Nix creates a builder entry

r[onix.remote_builder.routing.invalid]

#### Scenario: The repaired route performs a remote build

- GIVEN the repaired configuration is active on `britton-desktop`
- WHEN Nix builds a new eligible derivation
- THEN the build executes on Aspen through `ssh-ng`
- AND the local daemon no longer reports an SSH connection failure for `10.10.10.1`

r[onix.remote_builder.routing.validation]
r[onix.remote_builder.routing.physical]
