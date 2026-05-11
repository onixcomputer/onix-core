# desktop-build-resources Specification

## Purpose
Define desktop-safe Nix build resource policy for `britton-desktop`, including bounded local build parallelism, Nix build cgroup accounting, daemon service resource controls, and any future hardware-specific CPU isolation evidence.

## Requirements
### Requirement: Bounded local Nix build parallelism
`britton-desktop` MUST configure local Nix build parallelism with explicit `max-jobs` and `cores` values that avoid multiplying every concurrent derivation by the full hardware-thread count.

#### Scenario: Resolved Nix settings are bounded
- **WHEN** the resolved `nix.settings.max-jobs` and `nix.settings.cores` values are inspected for `britton-desktop`
- **THEN** both values MUST be explicit positive integers
- **AND** `max-jobs * cores` MUST NOT exceed the implementation's documented desktop-safe local build budget
- **AND** `cores` MUST NOT be `0`

### Requirement: Nix build cgroups are enabled
`britton-desktop` MUST enable Nix build cgroups so daemon-managed builds have resource accounting and can support cgroup-based constraints.

#### Scenario: Nix config exposes cgroup use
- **WHEN** `nix config show` or the resolved NixOS configuration is inspected for `britton-desktop`
- **THEN** `use-cgroups` MUST be enabled for Nix builds

### Requirement: nix-daemon runs below interactive desktop priority
`britton-desktop` MUST configure `nix-daemon.service` resource controls so build work has lower CPU and IO priority than interactive desktop workloads and applies memory pressure before the machine becomes unresponsive.

#### Scenario: Service resource controls are resolved
- **WHEN** `systemd.services.nix-daemon.serviceConfig` is inspected for `britton-desktop`
- **THEN** CPU and IO weights MUST be set below the default interactive service weight
- **AND** at least one memory pressure guard such as `MemoryHigh` or an equivalent cgroup memory limit MUST be configured

#### Scenario: Desktop remains schedulable during builds
- **WHEN** the operator checks systemd cgroup status while a representative Rust/Nix build runs locally under `nix-daemon.service`
- **THEN** build processes MUST remain children of the constrained daemon cgroup
- **AND** the desktop session MUST remain usable without input or compositor stalls attributable to unrestricted build scheduling

### Requirement: Hardware-specific CPU isolation is explicit and verifiable
If `britton-desktop` reserves CPU threads for interactive desktop work, the configuration MUST document the selected CPU set, the hardware/topology evidence behind it, and the intended fallback if topology changes.

#### Scenario: CPU affinity is checked against topology
- **GIVEN** the implementation uses `AllowedCPUs` or an equivalent CPU-affinity mechanism for `nix-daemon.service`
- **WHEN** the CPU topology and CPPC/preferred-core evidence are inspected on `britton-desktop`
- **THEN** the reserved CPU set MUST be documented in the implementation or evidence
- **AND** the evaluated service configuration MUST match the documented CPU set
