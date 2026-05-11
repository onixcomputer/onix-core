## Why

Two infrastructure paths need a single scoped repair plan before implementation:

1. `britton-air` is advertised as a remote builder at `192.168.1.60`, but this workstation currently reports `ssh: connect to host 192.168.1.60 port 22: No route to host`. On Linux clients, evaluated `nix.buildMachines` includes only the top-level Darwin endpoint for `aarch64-darwin`; the Apple Silicon `nix.linux-builder` VM can build `aarch64-linux` only for local builds launched on `britton-air`, not for remote Linux clients.
2. `aspen1` has an active Thunderbolt bridge (`br-tbt` at `10.10.10.1/28`) with two enslaved `thunderbolt-net` links, but recent kernel logs show host disconnects, retimer churn, and repeated `failed to send properties changed notification` events. The current recovery daemon only reacts to `hop deactivation failed`, so this observed failure class is not remediated or health-checked.

## What Changes

- **Remote builder routing and capability model**: Make `britton-air`/Apple-Silicon Linux builder behavior explicit and testable. Do not advertise unreachable or non-delegable systems from clients that cannot use them.
- **Connectivity preflight**: Add deterministic checks that fail when declared builders are unreachable from a client profile or advertise systems/features they cannot actually serve.
- **Aspen1 Thunderbolt recovery**: Extend the `thunderbolt-link` module to monitor observed aspen1 failure signatures and provide bounded, low-risk recovery for affected `thunderbolt-net` ports/bridge state.
- **Operational validation**: Document and script live validation commands for `britton-air`, its Linux builder VM, and `aspen1` Thunderbolt.

## Capabilities

### Modified Capabilities
- `remote-builders`: Remote builder declarations must reflect reachable SSH endpoints and real build systems/features for the consuming machine.
- `thunderbolt-link`: Thunderbolt host-to-host networking must recover from observed aspen1 link churn, not only `hop deactivation failed`.

## Impact

- **Files**: `inventory/tags/builder-targets.ncl`, `inventory/tags/remote-builders.nix`, `inventory/tags/thunderbolt-link.nix`, `machines/britton-air/configuration.nix`, optional validation scripts/checks under `flake-outputs/` or `pkgs/`.
- **APIs**: No external API changes; changes affect generated Nix/Clan machine config.
- **Dependencies**: Prefer no new runtime dependencies beyond existing NixOS/macOS tools (`ssh`, `nix`, `iproute2`, `systemd`, `networkctl`).
- **Testing**: Nix/Nickel evaluation, builder-list assertions, and live SSH/network probes against reachable hosts.
