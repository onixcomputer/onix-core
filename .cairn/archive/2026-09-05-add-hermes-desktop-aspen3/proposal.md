## Why

`hermes-agent` (the CLI) is already installed on every `llm-client` machine through the managed `llm-agents` clan service, including `aspen3`. The `hermes-desktop` package in the same pinned `llm-agents` flake provides the Electron desktop companion app ("Hermes Agent - Self-improving AI assistant desktop app"). `aspen3` is brittonr's interactive Niri workstation, so the desktop app belongs there; the other `llm-client` machines (e.g. `britton-desktop`) should not change.

## What Changes

- Add a per-machine override to the `llm-agents` service instance in `inventory/services/services.ncl`: for `aspen3` only, extend its package list with `hermes-desktop`. The clan service module system concatenates list-typed settings, so the shared CLI set stays intact and no other machine is affected.
- The Nickel-validated settings contracts must keep accepting the `packages` field for the `llm-agents` role, with positive and negative coverage.

## Impact

- **Files**: `inventory/services/services.ncl`, `inventory/services/fixtures/llm-agents-validation.ncl`, `flake-outputs/_module-checks.nix`, `.cairn/changes/add-hermes-desktop-aspen3/*`.
- **Risk**: None beyond `aspen3` gaining one more desktop package. No systemd services, no secrets, no architecture changes.
- **Non-goals**: No new clan service module (the `llm-agents` module already exists). No home-manager profile for the app (system install is sufficient on the single-user `aspen3` host). No change to the `hermes-matrix-gateway` instance on `britton-desktop`.
- **Testing**: Validate the Nickel inventory contracts, build the `hermes-desktop` package from the pinned input, evaluate the `aspen3` configuration to confirm the package lands in `environment.systemPackages`, and confirm `britton-desktop` is unchanged. Run positive and negative `llm-agents` settings checks, then the Cairn gates.
