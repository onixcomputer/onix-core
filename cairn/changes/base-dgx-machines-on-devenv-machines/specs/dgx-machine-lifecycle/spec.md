# DGX Machine Lifecycle Specification Delta

## Purpose

Define a device-free DGX machine lifecycle on the experimental Devenv machines interface, with typed data and fail-closed safety rules.

## ADDED Requirements

### Requirement: The experimental interface uses an isolated exact pin

r[onix.dgx_devenv.pin] The repository MUST pin the experimental Devenv machines implementation to an exact commit and isolate it from the default development shell.

#### Scenario: The canary pin matches the reviewed pull request

r[onix.dgx_devenv.pin.exact]
- GIVEN the DGX machine adapter evaluates
- WHEN it selects its Devenv implementation
- THEN the source revision is `6e61f6a12f730b81228f70ee2487320fdbb1e2fc`
- AND the default development shell keeps its independent Devenv input

#### Scenario: The upstream interface changes

r[onix.dgx_devenv.pin.drift]
- GIVEN the canary input no longer provides the reviewed NixOS machine interface
- WHEN compatibility checks evaluate
- THEN the checks fail with the missing interface name
- AND no fallback selects a moving branch or a different revision

### Requirement: Devenv is the only owner of declared DGX machines

r[onix.dgx_devenv.ownership] A declared DGX machine MUST have Devenv as its only lifecycle owner.

#### Scenario: A DGX name exists only in Devenv

r[onix.dgx_devenv.ownership.unique]
- GIVEN a DGX machine name exists in the typed DGX inventory
- WHEN ownership validation compares machine sets
- THEN the name is absent from the Clan machine set
- AND Devenv exposes that name once

#### Scenario: A DGX name also exists in Clan

r[onix.dgx_devenv.ownership.conflict]
- GIVEN the same machine name exists in the DGX and Clan machine sets
- WHEN ownership validation evaluates
- THEN evaluation fails before a build, connection, deploy, or install action
- AND the diagnostic names the duplicate owner sets

### Requirement: DGX machine data is typed and complete

r[onix.dgx_devenv.inventory] Nickel MUST be the source for DGX identity, target, hardware, storage, access, backend ownership, and runtime secret names.

#### Scenario: No real DGX facts are available

r[onix.dgx_devenv.inventory.empty]
- GIVEN the operator has not supplied real DGX machine facts
- WHEN the production inventory exports
- THEN it exports an empty machine map
- AND the adapter does not invent a machine, target, disk, UUID, or host key

#### Scenario: A real machine record is complete

r[onix.dgx_devenv.inventory.complete]
- GIVEN a record contains all required real facts
- WHEN Nickel validates and exports the record
- THEN deterministic generated data contains the same non-secret facts
- AND a freshness check accepts the generated data

#### Scenario: A machine record contains an unsafe value

r[onix.dgx_devenv.inventory.invalid]
- GIVEN a record has an empty value, placeholder, unsupported system, `/dev/nvme*` disk, or absent facter report
- WHEN Nickel validates the record
- THEN export fails with the invalid field name
- AND Nix does not receive a partial machine record

### Requirement: DGX policy uses one reusable NixOS module graph

r[onix.dgx_devenv.services] Devenv DGX machines and DGX policy checks MUST use the same plain NixOS module graph.

#### Scenario: A DGX closure evaluates

r[onix.dgx_devenv.services.parity]
- GIVEN a valid synthetic DGX machine record
- WHEN the Devenv machine evaluates its NixOS closure
- THEN the closure includes the upstream DGX Spark module
- AND it includes OpenSSH, Tailscale, Sendme, iroh-ssh, and Mesh-LLM
- AND Mesh-LLM resolves its bind address from `tailscale0` at service start

#### Scenario: Clan wrappers consume a shared service core

r[onix.dgx_devenv.services.core]
- GIVEN Tailscale, iroh-ssh, or Mesh-LLM settings
- WHEN a Clan wrapper and a plain DGX module lower equivalent settings
- THEN both shells consume the same pure settings-to-Nix core
- AND focused checks detect a service-policy difference

#### Scenario: A loopback Mesh-LLM backend has no owner

r[onix.dgx_devenv.services.backend]
- GIVEN Mesh-LLM uses a loopback backend without a declared backend unit or external owner
- WHEN the DGX machine evaluates
- THEN evaluation fails with the missing backend owner
- AND the service does not start with an unmanaged dependency

### Requirement: DGX access stays Framework-key-only

r[onix.dgx_devenv.access] Each DGX NixOS closure MUST authorize only the Framework SSH public key for `brittonr` and `root`.

#### Scenario: The DGX user policy evaluates

r[onix.dgx_devenv.access.framework]
- GIVEN a valid DGX closure
- WHEN its user and OpenSSH options evaluate
- THEN `brittonr` has UID `1555` and wheel access
- AND `brittonr` and `root` each have only the Framework key

#### Scenario: Another shared key enters the module graph

r[onix.dgx_devenv.access.reject]
- GIVEN the cproof.ai key or an auto-discovered builder key enters a shared module
- WHEN the final DGX authorized-key sets evaluate
- THEN neither key occurs in either DGX user
- AND a negative fixture fails if the Framework-only force is removed

### Requirement: Runtime secrets stay outside Nix data

r[onix.dgx_devenv.secrets] DGX services MUST read runtime files that Devenv installs from declared SecretSpec names.

#### Scenario: A service uses a secret

r[onix.dgx_devenv.secrets.runtime]
- GIVEN a DGX service needs a Tailscale, iroh-ssh, or Mesh-LLM secret
- WHEN an authorized installation resolves the declared SecretSpec name
- THEN Devenv atomically installs a private root-owned runtime file
- AND systemd supplies the Mesh-LLM join token through a credential file
- AND Mesh-LLM receives only the credential path through `--join-file`
- AND no secret value occurs in Nickel, generated inventory data, Nix options, command arguments, logs, or store paths

#### Scenario: A required runtime secret is absent

r[onix.dgx_devenv.secrets.missing]
- GIVEN a service declares a required SecretSpec name without an installed runtime file
- WHEN the service starts
- THEN the service fails before it joins a network
- AND the log identifies the missing credential file without its value

### Requirement: The initial DGX command surface is device-free

r[onix.dgx_devenv.build] The repository DGX command MUST expose only machine information and device-free build operations in this change.

#### Scenario: An operator requests machine information

r[onix.dgx_devenv.build.info]
- GIVEN valid generated DGX inventory data
- WHEN the operator invokes `dgx-machine info`
- THEN the command uses the pinned Devenv CLI
- AND it does not open a target connection

#### Scenario: An operator builds a DGX machine

r[onix.dgx_devenv.build.closure]
- GIVEN a declared DGX machine has complete facts
- WHEN the operator invokes `dgx-machine build <name>`
- THEN the command builds the NixOS closure and Disko script
- AND it does not copy, activate, install, reboot, or repartition a target

#### Scenario: An operator requests a destructive command

r[onix.dgx_devenv.build.reject]
- GIVEN an operator requests `deploy`, `install`, or an unknown subcommand
- WHEN the repository command parses the request
- THEN it rejects the request before process execution
- AND the diagnostic states that a separate authorized Cairn change is required

### Requirement: Storage checks fail closed

r[onix.dgx_devenv.storage] Every declared DGX machine MUST use a reviewed stable disk identifier and a machine-specific hardware report.

#### Scenario: A valid Disko script evaluates

r[onix.dgx_devenv.storage.valid]
- GIVEN a complete synthetic machine record uses `/dev/disk/by-id/...`
- WHEN its Disko script evaluates
- THEN the script contains that exact identifier
- AND no generic NVMe device path replaces it

#### Scenario: An unstable disk path enters inventory

r[onix.dgx_devenv.storage.reject]
- GIVEN a machine record uses `/dev/nvme0n1` or an example disk value
- WHEN inventory validation evaluates
- THEN validation fails before the Disko script builds
- AND no destructive command becomes available

### Requirement: Validation has positive and negative device-free evidence

r[onix.dgx_devenv.validation] The DGX lifecycle checks MUST cover success and rejection paths without target access.

#### Scenario: The device-free gate passes

r[onix.dgx_devenv.validation.positive]
- GIVEN the production machine map is empty or contains complete records
- WHEN the DGX validation gate runs
- THEN Nickel export, generated-data freshness, ownership, interface, module, closure, and Disko checks pass
- AND the test process makes no SSH connection

#### Scenario: A safety rule regresses

r[onix.dgx_devenv.validation.negative]
- GIVEN a fixture adds duplicate ownership, an unsafe disk, a wrong key, a secret value, or a destructive command
- WHEN the related check runs
- THEN that check fails with the violated rule
- AND unrelated checks remain device-free
