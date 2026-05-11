## Context

Research evidence gathered 2026-05-11:

- `ssh -o BatchMode=yes -o ConnectTimeout=5 brittonr@192.168.1.60 ...` from this workstation failed with `No route to host`.
- `nix eval .#nixosConfigurations.britton-desktop.config.nix.buildMachines --option allow-import-from-derivation true` includes `aspen1` at `10.10.10.1` for `x86_64-linux` and `britton-air` at `192.168.1.60` for `aarch64-darwin`.
- `nix eval .#nixosConfigurations.aspen1.config.nix.buildMachines --option allow-import-from-derivation true` includes only `britton-air` at `192.168.1.60` for `aarch64-darwin`.
- `machines/britton-air/configuration.nix` enables `nix.linux-builder`, but that supports local builds launched on `britton-air`; it does not make the nested builder VM a routable remote endpoint for Linux clients.
- Live `aspen1.local` inspection showed `thunderbolt0`, `thunderbolt1`, and `br-tbt` up; `br-tbt` has `10.10.10.1/28`; `networkctl` reports the Thunderbolt members enslaved/configured.
- Aspen1 kernel logs from the last week show retimer disconnect/reconnect, host disconnect/reconnect for `Linux britton-desktop`, and repeated `failed to send properties changed notification` messages.

## Goals / Non-Goals

**Goals:**

- Make remote builder declarations truthful for each consuming machine.
- Fix or filter the unreachable `britton-air` remote builder path.
- Preserve `britton-air`'s local `nix.linux-builder` utility for local Apple Silicon builds.
- Extend aspen1 Thunderbolt recovery to observed retimer/host/property-notification failure classes.
- Add deterministic checks so this does not regress silently.

**Non-Goals:**

- Reinstalling `britton-air` or replacing the UTM VM design in this change.
- Advertising a nested Linux builder through the Darwin host without an explicit, routable SSH endpoint and trust/key model.
- Reworking all machine inventory networking beyond the builder/thunderbolt paths.

## Decisions

### 1. Treat builder reachability as consumer-relative

**Choice:** Add configuration/validation that can include or exclude builder targets per consuming machine or network path.

**Rationale:** The current Nickel target list is global. That catches typos, but it cannot express that `192.168.1.60` is unusable from some clients while `10.10.10.1` is valid over Thunderbolt.

**Alternative:** Keep `britton-air` globally listed and rely on Nix to skip failed builders. Rejected because repeated SSH failures slow builds and hide configuration drift.

**Implementation:** Extend builder target metadata with an allow/deny mechanism or reachable-network class, then filter in `remote-builders.nix`. Add an eval check that asserts known clients do not include unreachable endpoints.

### 2. Do not conflate `britton-air` with its nested Linux builder

**Choice:** Keep `britton-air` as `aarch64-darwin` only unless a separate Linux VM endpoint is declared.

**Rationale:** `nix.linux-builder` is configured inside nix-darwin for local offload. Remote Linux clients connecting to the Darwin host cannot assume nested `aarch64-linux` builder semantics.

**Alternative:** Advertise `aarch64-linux` on `britton-air` directly. Rejected because it would be inaccurate and likely fail or build on the wrong platform.

**Implementation:** If remote `aarch64-linux` capacity is needed, declare a separate inventory machine for the VM with SSH host/address/key and validate it independently.

### 3. Aspen1 recovery should be pattern-driven and rate-limited

**Choice:** Extend `thunderbolt-net-recovery` matching to cover retimer disconnect, host disconnect, and repeated properties-changed notification failures, with a debounce/rate limit and post-check.

**Rationale:** Live logs show degraded churn not covered by the current single `hop deactivation failed` match.

**Alternative:** Restart `systemd-networkd` or reboot aspen1. Rejected as too broad for a link-local driver wedge.

**Implementation:** Keep the existing narrow interface bounce, add failure-burst detection, reset qdisc, re-up interfaces, optionally reconfigure `br-tbt`, and emit health status based on `ip -br addr show br-tbt` plus optional peer pings.

## Risks / Trade-offs

**Over-filtering builders** → Mitigate with explicit eval checks for expected builder lists per host.

**Thunderbolt false positives causing flaps** → Mitigate with burst thresholds, cooldown state, and clear journal logging.

**MacBook reachability depends on physical network/power/lid state** → Mitigate by validating `pmset`/SSH separately and not advertising the builder where unreachable.

## Validation Plan

- Run Nickel export/evaluation for `inventory/tags/builder-targets.ncl`.
- Evaluate `nix.buildMachines` for `britton-desktop`, `aspen1`, and `bonsai` with `--option allow-import-from-derivation true`.
- Add/extend a flake check that rejects self-builders, unreachable disallowed endpoints, and system-feature mismatches.
- Live-check `ssh` to accepted builder endpoints.
- On aspen1, inspect `ip -br addr`, `networkctl`, journal recovery messages, and peer reachability over `br-tbt`.
