## MODIFIED Requirements

### Requirement: Builder declarations match reachable endpoints

The system MUST only include a remote builder in a machine's `nix.buildMachines` list when that builder's SSH endpoint is expected to be reachable from that machine and the declared `systems` can be served by that endpoint.

#### Scenario: Linux client evaluates britton-air

- GIVEN a Linux client using the `remote-builders` tag
- AND `britton-air` is not routable from that client on the declared address
- WHEN the client's `nix.buildMachines` is evaluated
- THEN the generated list MUST NOT advertise `britton-air` as a usable remote builder for that client.

#### Scenario: Darwin host owns its nested Linux builder

- GIVEN `britton-air` has `nix.linux-builder.enable = true`
- WHEN a build is launched locally on `britton-air`
- THEN `aarch64-linux` work MAY be delegated to the local nix-darwin Linux builder VM.
- AND other clients MUST NOT assume that nested VM is reachable through the top-level Darwin SSH endpoint unless an explicit routable VM endpoint is declared and validated.

### Requirement: Builder capability checks are machine-relative

The system MUST validate remote builder capability from the perspective of the consuming machine, not only from global inventory data.

#### Scenario: Unsupported system is filtered or rejected

- GIVEN a builder target advertises `aarch64-darwin`
- AND a Linux client cannot reach that builder endpoint
- WHEN validation runs for that client's generated `nix.buildMachines`
- THEN validation MUST fail with a diagnostic naming the consuming machine, builder name, address, and system.

#### Scenario: Declared Linux VM endpoint is reachable

- GIVEN a future `britton-air` Linux builder VM endpoint is added to inventory
- WHEN validation runs from a client that is allowed to use it
- THEN the check MUST verify SSH reachability and `nix show-config`/system evidence before accepting `aarch64-linux` in `nix.buildMachines`.
