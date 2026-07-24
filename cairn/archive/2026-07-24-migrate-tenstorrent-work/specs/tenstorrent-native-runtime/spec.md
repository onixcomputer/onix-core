# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: Dedicated repository owns reusable Tenstorrent packages
r[onix.tenstorrent.native_runtime.dedicated_repository] Onix SHALL publish reusable Tenstorrent packages, device-free validation checks, bounded ttWKV7 wrappers, and retained evidence fixtures from the `OnixResearch/tenstorrent.nix` `main` branch while fleet-specific configuration remains in `onix-core`, and `onix-core` SHALL consume the dedicated flake without retaining duplicate package sources.

#### Scenario: Dedicated package authority is consumed
- GIVEN a validated `OnixResearch/tenstorrent.nix` revision containing the migrated outputs
- WHEN `onix-core` evaluates its pinned Tenstorrent input
- THEN each migrated package and check resolves from the dedicated flake
- AND host-specific configuration continues to instantiate parameterized outputs without a duplicate local package tree

#### Scenario: Migration boundary is violated
- GIVEN a candidate migration that omits a declared reusable output, imports fleet secrets or unrelated work, or leaves `onix-core` using a duplicate local source
- WHEN repository-boundary validation runs
- THEN validation fails instead of treating the migration as complete

#### Scenario: Device-free validation is performed
- GIVEN the standalone flake on a host where no accelerator is acquired
- WHEN its focused migration checks run
- THEN positive package and evidence fixtures pass
- AND malformed, incomplete, or unsupported inputs are rejected before device initialization
