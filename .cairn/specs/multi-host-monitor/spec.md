# Multi Host Monitor Specification

## Purpose

Install an authenticated read-only Iroh system monitor on two selected Onix machines and give the desktop a pinned, usable terminal dashboard.

## Requirements

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

### Requirement: Explicit reachable-host enrollment [r[onix.meshtop.reachable-fleet]]

The operator MUST check each declared core-inventory machine through its configured or documented SSH route using strict host-key checking and noninteractive authentication. Only a host with verified access and an explicitly configured Meshtop agent MAY be added to the pinned desktop roster. A failed, offline, or untrusted SSH target MUST NOT be represented as an active Meshtop agent. Inventory tags MUST NOT enable the service fleet-wide.

#### Scenario: Selected reachable machine [r[onix.meshtop.reachable-fleet.selection]]

- GIVEN Bonsai is SSH-reachable and its agent is enabled explicitly in its own onix-core machine configuration
- WHEN the operator installs the generated unit and observes its public endpoint ID
- THEN the desktop roster pins that ID alongside the existing Aspen3 and britton-desktop IDs
- AND each machine retains a distinct private key outside Nix evaluation and the store

#### Scenario: Unreachable machine [r[onix.meshtop.reachable-fleet.offline]]

- GIVEN an inventory machine's declared and documented alternate SSH routes fail a strict noninteractive connection
- WHEN the desktop roster is regenerated
- THEN that machine is not added as though its agent were deployed
- AND its NixOS Meshtop service remains disabled absent explicit host enrollment

### Requirement: Authenticated expanded dashboard [r[onix.meshtop.reachable-view]]

Each newly enrolled agent MUST admit only the existing desktop viewer ID. The desktop viewer MUST retain authenticated samples and independent status for every pinned host and MUST allow navigation to hosts outside the visible grid without swapping or silently dropping roster entries. A selected-host failure MUST NOT erase a healthy host's most recent observation.

#### Scenario: Three reachable hosts [r[onix.meshtop.reachable-view.live]]

- GIVEN the Aspen3, britton-desktop, and Bonsai agents are running with different persistent identities and one pinned viewer ID
- WHEN the authorized desktop viewer requests a three-host sample
- THEN it receives a current snapshot for each named host without changing the original two agent IDs
- AND the terminal can display or scroll to Bonsai while retaining each host's own status and CPU, memory, GPU-availability, network, disk, and process observations

#### Scenario: Restricted viewer [r[onix.meshtop.reachable-view.auth]]

- GIVEN the Bonsai agent is authorized for the existing desktop viewer ID
- WHEN an unrelated viewer identity requests its snapshot
- THEN Bonsai refuses that request without exposing telemetry or changing its stored agent identity

### Requirement: Bounded hardware model telemetry [r[onix.meshtop.hardware-model]]

An agent MUST report its CPU's host-reported brand when available and MUST use the corresponding read-only PCI device model from the host's udev database for an AMD GPU when available. Hardware labels MUST be bounded and sanitized before transmission. A missing GPU model MUST be represented by the numeric PCI identity when available or an explicit unavailable model, never a fabricated marketing name. Agents MUST continue to accept only the pinned viewer identity and send no command-line or secret data.

#### Scenario: Named CPU and AMD GPU [r[onix.meshtop.hardware-model.named]]

- GIVEN an enrolled agent with a reported CPU brand and an AMD DRM card whose PCI entry has a model name
- WHEN the authorized viewer requests a sample
- THEN its snapshot contains the CPU brand and the AMD PCI device's model label alongside the existing CPU, memory and GPU counters
- AND the same agent endpoint identity remains pinned

#### Scenario: Missing or oversized PCI model [r[onix.meshtop.hardware-model.fallback]]

- GIVEN an AMD card without a usable bounded PCI database name
- WHEN the agent discovers the GPU
- THEN its label uses the card's numeric PCI ID when present, or explicitly says its model is unavailable
- AND missing counters remain unavailable rather than idle

### Requirement: Hardware names in every supported dashboard mode [r[onix.meshtop.hardware-view]]

The viewer MUST show the reported CPU and GPU model names in compact and full live panels while preserving utilization, VRAM, temperatures, network, filesystems, and process observations. An older agent snapshot without the optional CPU model MUST still decode and MUST show an explicit unavailable CPU model; an offline host MUST retain its last known model without presenting stale counters as live.

#### Scenario: Responsive three-host display [r[onix.meshtop.hardware-view.grid]]

- GIVEN Aspen3, britton-desktop and Bonsai have upgraded agents and their original pinned IDs
- WHEN the desktop viewer receives samples for all three
- THEN each panel identifies its CPU and AMD GPU by their host-reported models or honest numeric fallback
- AND the narrow view can scroll to Bonsai without losing the other hosts' state or readings

#### Scenario: Older agent still paired [r[onix.meshtop.hardware-view.legacy]]

- GIVEN a valid prior-version sample without a CPU model field
- WHEN the new viewer displays it
- THEN the host stays paired and the viewer labels the CPU model unavailable instead of inventing a model

### Requirement: Explicit external user-agent enrollment [r[onix.meshtop.leviathan-agent]]

Leviathan MUST be reached through a verified strict, noninteractive SSH route before enrollment. Its selected user unit MUST start the read-only Meshtop agent from an exact reviewed source revision, keep its private identity on Leviathan with owner-only permissions, and admit only the existing desktop viewer public identity. The unit MUST NOT imply that Leviathan is an onix-core NixOS inventory machine. A report of boot or post-logout availability MUST NOT be made while that user's manager reports `Linger=no`.

#### Scenario: Selected external host [r[onix.meshtop.leviathan-agent.selected]]

- GIVEN Leviathan is reachable as the intended user and Meshtop's exact published source revision is built on that host
- WHEN its user agent starts with the pinned desktop viewer public identity and a new on-host private key
- THEN the observed new agent public identity can be pinned in the desktop roster
- AND neither private key nor unrelated machine generations are changed

#### Scenario: Unavailable administrator authorization [r[onix.meshtop.leviathan-agent.linger]]

- GIVEN the user unit is enabled and active while sessions exist but `Linger=no`
- WHEN the operator records the deployment evidence
- THEN the evidence MUST describe the agent as session-scoped and require an authorized administrator to enable lingering before making a logout/boot continuity claim

### Requirement: Four independently pinned read-only snapshots [r[onix.meshtop.leviathan-view]]

The generated desktop roster MUST preserve the Aspen3, britton-desktop and Bonsai IDs and append only Leviathan's observed agent ID. The existing viewer MUST obtain separate authenticated snapshots for all four hosts, and the narrow TUI MUST allow navigating to Leviathan's card. An unsupported GPU counter MUST remain unavailable instead of reporting a fabricated zero or GPU model. The agent MUST NOT disclose snapshots to an unrelated viewer identity.

#### Scenario: Live four-host dashboard [r[onix.meshtop.leviathan-view.live]]

- GIVEN all four agents are online and admit the pinned desktop viewer identity
- WHEN that viewer samples the generated four-host roster and pages through the compact dashboard
- THEN it receives four distinct, currently live CPU, memory, network, filesystem and process snapshots and can reach Leviathan's CPU card
- AND Leviathan's unsupported GPU counter is shown as unavailable

#### Scenario: Unpaired viewer [r[onix.meshtop.leviathan-view.auth]]

- GIVEN Leviathan's agent authorizes only the paired desktop viewer public identity
- WHEN a different viewer identity requests a snapshot
- THEN the agent MUST NOT return its telemetry to that viewer
