# Aspen3 and Desktop meshtop Specification Delta

## Purpose

Install an authenticated read-only Iroh system monitor on two selected Onix machines and give the desktop a pinned, usable terminal dashboard.

## ADDED Requirements

### Requirement: Pinned meshtop source package [r[onix.meshtop.package]]

The onix-core Linux flake MUST build meshtop solely from an exact committed source revision imported by a repo-owned script with its Cargo.lock. No deployed Nix derivation may read a sibling workspace path.

#### Scenario: Package can be rebuilt [r[onix.meshtop.package.build]]

- GIVEN the recorded meshtop revision and imported files
- WHEN the x86_64-linux package builds
- THEN its store output contains the real `meshtop` CLI
- AND the sync script rejects a mismatched or dirty source revision

### Requirement: Aspen3 agent [r[onix.meshtop.aspen3]]

Aspen3 MUST install meshtop and run a restartable read-only agent as an unprivileged service with a private durable identity that admits only the pinned desktop viewer ID.

#### Scenario: Aspen3 telemetry and key persistence [r[onix.meshtop.aspen3.live]]

- GIVEN the selected machine configuration is activated
- WHEN the desktop viewer requests a sample and the agent restarts
- THEN the authorized viewer receives a bounded CPU/memory sample for Aspen3
- AND the agent retains its public ID across restart without exposing its private seed in Nix/store or logs

### Requirement: Desktop agent and viewer [r[onix.meshtop.desktop]]

britton-desktop MUST install the terminal viewer and run its own separately keyed user agent authorized for the same pinned viewer ID. The selected Home Manager profile MUST declare the service and public-ID roster; the desktop NixOS system service MUST remain disabled. Other inventory hosts MUST NOT gain an agent from a shared tag. The viewer MUST show telemetry and status for both pinned hosts at once when the terminal fits both panels, with row scrolling when the roster exceeds the visible area.

#### Scenario: Desktop monitoring [r[onix.meshtop.desktop.live]]

- GIVEN the desktop's onix-core-generated Home Manager unit, roster, and package are activated for the `brittonr` user
- WHEN the viewer opens the two-host roster in a terminal that fits both panels
- THEN Aspen3 and britton-desktop display their own CPU, memory, disk, process, and status observations without host selection
- AND that agent's ID differs from Aspen3's and the viewer's ID

#### Scenario: Viewport overflow [r[onix.meshtop.desktop.scroll]]

- GIVEN more hosts than the terminal can fit at once
- WHEN the viewer scrolls down one row
- THEN the next host's telemetry and status become visible without changing the pinned roster

### Requirement: Bounded GPU telemetry and themed per-host panels [r[onix.meshtop.gpu]]

Each selected agent MUST sample available AMD GPU busy percentage, VRAM, temperature, and clock counters from bounded read-only DRM sysfs observations; unavailable counters MUST remain absent rather than becoming zero. The viewer MUST display each host's GPU observations alongside clearly labeled CPU, memory, network, disk, and process panels with colored meters and textual values/status. A viewer paired with a pre-GPU agent MUST display a distinct unreported state. These observations MUST NOT claim Tenstorrent accelerator or unsupported-vendor GPU telemetry.

#### Scenario: Paired GPU metrics [r[onix.meshtop.gpu.live]]

- GIVEN Aspen3 and britton-desktop each run the updated agent with readable AMD GPU counters
- WHEN the paired desktop viewer opens the two-host dashboard
- THEN both pinned hosts show their own bounded GPU utilization and VRAM, with available temperature and clock, in the same terminal without switching selection
- AND the terminal retains visible CPU, memory, disk, process and per-host status observations at wide and narrow sizes

#### Scenario: Missing or older GPU observations [r[onix.meshtop.gpu.missing]]

- GIVEN an agent predating GPU telemetry, a host without supported AMD GPU counters, or an unreadable individual sensor
- WHEN the viewer renders the sample
- THEN unavailable GPU data is labeled as unreported or unavailable, not presented as a zero reading or a fresh observation from another host

### Requirement: Pinned two-host roster and verification [r[onix.meshtop.verify]]

The viewer roster MUST pin both observed agent IDs; both agents MUST reject unpaired viewer identities. The rollout MUST preserve the prior flake.lock change and distinguish the Aspen3 NixOS activation, the desktop's selected user-artifact activation, and live network observations; it MUST NOT claim the blocked whole-desktop NixOS generation was switched.

#### Scenario: Authorized and unauthorized requests [r[onix.meshtop.verify.auth]]

- GIVEN Aspen3's NixOS configuration and the desktop user service are activated with the pinned viewer ID
- WHEN the desktop runs `watch --once` with its two-host roster
- THEN it receives real samples for each named host
- AND a different viewer key cannot receive either host's sample

#### Scenario: Negative host selection [r[onix.meshtop.verify.selection]]

- GIVEN an unrelated inventory machine
- WHEN its NixOS configuration is evaluated
- THEN meshtop is not enabled there by the shared service module
