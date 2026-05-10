## ADDED Requirements

### Requirement: Bounded local Nix build parallelism [r[desktop-build.nix-parallelism]]
`britton-desktop` MUST configure local Nix build parallelism with explicit `max-jobs` and `cores` values that avoid multiplying every concurrent derivation by the full hardware-thread count.

#### Scenario: Resolved Nix settings are bounded [r[desktop-build.nix-parallelism.resolved]]
- GIVEN the `britton-desktop` NixOS configuration is evaluated
- WHEN the resolved `nix.settings.max-jobs` and `nix.settings.cores` values are inspected
- THEN both values are explicit positive integers
- AND `max-jobs * cores` does not exceed the implementation's documented desktop-safe local build budget
- AND `cores` is not `0`

### Requirement: Nix build cgroups are enabled [r[desktop-build.nix-cgroups]]
`britton-desktop` MUST enable Nix build cgroups so daemon-managed builds have resource accounting and can support cgroup-based constraints.

#### Scenario: Nix config exposes cgroup use [r[desktop-build.nix-cgroups.resolved]]
- GIVEN the deployed or evaluated `britton-desktop` Nix configuration
- WHEN `nix config show` or the resolved NixOS config is inspected
- THEN `use-cgroups` is enabled for Nix builds

### Requirement: nix-daemon runs below interactive desktop priority [r[desktop-build.daemon-resources]]
`britton-desktop` MUST configure `nix-daemon.service` resource controls so build work has lower CPU and IO priority than interactive desktop workloads and applies memory pressure before the machine becomes unresponsive.

#### Scenario: Service resource controls are resolved [r[desktop-build.daemon-resources.resolved]]
- GIVEN the `britton-desktop` systemd service configuration is evaluated
- WHEN `systemd.services.nix-daemon.serviceConfig` is inspected
- THEN CPU and IO weights are set below the default interactive service weight
- AND at least one memory pressure guard such as `MemoryHigh` or an equivalent cgroup memory limit is configured

#### Scenario: Desktop remains schedulable during builds [r[desktop-build.daemon-resources.runtime]]
- GIVEN a representative Rust/Nix build is running locally under `nix-daemon.service`
- WHEN the operator checks systemd cgroup status and desktop responsiveness
- THEN build processes remain children of the constrained daemon cgroup
- AND the desktop session remains usable without input or compositor stalls attributable to unrestricted build scheduling

### Requirement: Hardware-specific CPU isolation is explicit and verifiable [r[desktop-build.cpu-isolation]]
If `britton-desktop` reserves CPU threads for interactive desktop work, the configuration MUST document the selected CPU set, the hardware/topology evidence behind it, and the intended fallback if topology changes.

#### Scenario: CPU affinity is checked against topology [r[desktop-build.cpu-isolation.topology]]
- GIVEN the implementation uses `AllowedCPUs` or an equivalent CPU-affinity mechanism for `nix-daemon.service`
- WHEN the CPU topology and CPPC/preferred-core evidence are inspected on `britton-desktop`
- THEN the reserved CPU set is documented in the implementation or evidence
- AND the evaluated service configuration matches the documented CPU set
