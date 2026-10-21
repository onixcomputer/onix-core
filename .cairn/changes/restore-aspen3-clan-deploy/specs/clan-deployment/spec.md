# Clan Deployment Specification Delta

## Purpose

`clan machines update` deploys managed machines from this repository.

## ADDED Requirements

### Requirement: Evaluate aspen3 from the repository

r[onix.clan_deploy.evaluation] The aspen3 toplevel MUST evaluate from the repository flake. Files that the configuration imports MUST be visible to Git, and vendored assets MUST name the package versions that their checks compare against.

#### Scenario: The pinned Grafana release changes

r[onix.clan_deploy.evaluation.grafana]
- GIVEN nixpkgs ships Grafana 13.1.6 with unchanged email templates
- WHEN the aspen3 toplevel is evaluated
- THEN the manifest version assertion passes
- AND the email-template check verifies all 18 vendored hashes

### Requirement: Build with GitHub SSH access

r[onix.clan_deploy.build_host] aspen3 MUST name a build host user whose SSH key reaches GitHub. A build host without a user resolves to root, which cannot fetch octet's GitHub-SSH cargo dependency on britton-desktop.

#### Scenario: Clan builds aspen3 on the desktop

r[onix.clan_deploy.build_host.fetch]
- GIVEN the aspen3 closure depends on `bounded-exec` over GitHub SSH
- WHEN `clan machines update aspen3` evaluates on britton-desktop
- THEN evaluation runs as brittonr and fetches the dependency
- AND the toplevel builds

### Requirement: Hand runtime units to the generation

r[onix.clan_deploy.handover] Units attached under `/etc/systemd/system.control`, and user files that Home Manager will own, MUST be moved to backups before the switch.

#### Scenario: Aspen3 services come under Clan management

r[onix.clan_deploy.handover.aspen3]
- GIVEN laya and mesh-llm are attached under `system.control` and the tunnel unit and OMP extension were installed by hand
- WHEN aspen3 switches to the Clan generation
- THEN both services load from `/etc/systemd/system`
- AND Home Manager links the tunnel unit and extension without `.hm-bak` files

### Requirement: Activate the generation

r[onix.clan_deploy.activation] `clan machines update aspen3` MUST register the generation for boot and activate it. Units that fail afterwards MUST be limited to units that failed before the switch.

#### Scenario: Pre-existing storage failures remain

r[onix.clan_deploy.activation.aspen3]
- GIVEN celld storage units fail while the USB4 NVMe is absent
- WHEN the deployment runs
- THEN it exits 0 with `/run/current-system` and the system profile at the new generation
- AND the only failed unit is `celld-site-storage-provision.service`
