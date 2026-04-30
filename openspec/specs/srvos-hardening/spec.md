# Srvos Hardening Specification

## Purpose

This specification records requirements synced from OpenSpec change `mic92-hardening`.

## Requirements

<!-- synced from openspec change: mic92-hardening -->
## ADDED Requirements

### Requirement: srvos input declared in flake
The flake SHALL declare `srvos` as an input from `github:nix-community/srvos` with `inputs.nixpkgs.follows = "nixpkgs"`.

#### Scenario: srvos input present in lock
- **WHEN** the flake is evaluated
- **THEN** `inputs.srvos` resolves to the nix-community/srvos repository and follows our nixpkgs

### Requirement: srvos common module applied to all NixOS machines
The `nixos` tag SHALL import `srvos.nixosModules.common` so every NixOS machine receives the srvos baseline (SSH hardening, systemd defaults, journal limits, etc.).

#### Scenario: new machine gets srvos defaults
- **WHEN** a machine is added with the `nixos` tag
- **THEN** the machine's NixOS configuration includes srvos common module settings

#### Scenario: srvos settings do not conflict with existing config
- **WHEN** the `nixos` tag is evaluated
- **THEN** any settings that srvos covers which we previously set manually SHALL be removed or use `mkForce` only where our value intentionally differs from srvos

### Requirement: srvos nix experimental features mixin applied
The `nixos` tag SHALL import `srvos.nixosModules.mixins-nix-experimental` to enable flakes and nix-command system-wide.

#### Scenario: flakes available on all machines
- **WHEN** a user runs `nix build` on any machine
- **THEN** the command succeeds without `--extra-experimental-features`

### Requirement: srvos trusted caches mixin applied
The `nixos` tag SHALL import `srvos.nixosModules.mixins-trusted-nix-caches` to trust community caches (nix-community cachix, etc.).

#### Scenario: community cache substitution works
- **WHEN** a machine builds a package available in nix-community cachix
- **THEN** the binary is fetched from the cache rather than built locally

### Requirement: redundant settings removed from nixos tag
Settings in `inventory/tags/nixos.nix` that are now provided by srvos modules SHALL be removed to avoid duplication and potential `mkDefault` priority conflicts.

#### Scenario: no duplicate nftables enable
- **WHEN** srvos common already enables nftables
- **THEN** our nixos tag does not redundantly set `networking.nftables.enable = true`

#### Scenario: no duplicate experimental features
- **WHEN** srvos mixins-nix-experimental enables flakes + nix-command
- **THEN** our nixos tag does not redundantly set `nix.settings.experimental-features`
