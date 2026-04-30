# Refactor Specification

## Purpose

This specification records requirements synced from OpenSpec change `remove-parts-folder`.

## Requirements

<!-- synced from openspec change: remove-parts-folder -->
## ADDED Requirements

### Requirement: Flake outputs remain identical after parts removal
All flake outputs (packages, checks, devShells, formatter) SHALL produce byte-identical results after the `parts/` directory is removed and its contents are consolidated into `flake-outputs/`.

#### Scenario: Package set unchanged
- **WHEN** `nix flake show` is run after the refactor
- **THEN** the set of packages, checks, and devShells is identical to before

#### Scenario: No dangling imports
- **WHEN** `nix flake check` is run after the refactor
- **THEN** no files reference `parts/` and all imports resolve
