# Ssh Config Specification

## Purpose

Maintain SSH aliases for each managed user's locally visible Tailscale devices without rebuilding the managed SSH configuration whenever membership changes.

## Requirements

### Requirement: Local assigned-name discovery [r[onix.ssh.tailscale.discovery]]

The updater MUST read the local Tailscale status at runtime, include Self and all peers regardless of online state, and derive aliases from assigned DNSName values rather than device-reported HostName values. Unique short names and full DNS names MUST resolve to validated IPv4 addresses. Ambiguous short names MUST NOT choose an arbitrary device; their full aliases MUST remain available.

#### Scenario: Offline and duplicate reported hostnames [r[onix.ssh.tailscale.discovery.names]]

- GIVEN locally visible devices with duplicate reported hostnames and distinct assigned DNS names, including an offline device
- WHEN discovery succeeds
- THEN OpenSSH selects the corresponding address for each assigned short and full alias
- AND the offline device remains listed

#### Scenario: Ambiguous short names [r[onix.ssh.tailscale.discovery.ambiguous]]

- GIVEN two visible domains assigning the same short name to different devices
- WHEN discovery succeeds
- THEN neither device is selected through an ambiguous generated short alias
- AND both full aliases select their own addresses

### Requirement: Preserve SSH policy and explicit routing [r[onix.ssh.tailscale.policy]]

The managed SSH config MUST include generated aliases after explicit host policy and routing overrides. Generated entries MUST NOT assign usernames, keys, or trust settings. Stale copied Tailscale addresses MUST be removed from static policy while intentional LAN/root routing and Git policy remain effective.

#### Scenario: Existing override precedence [r[onix.ssh.tailscale.policy.precedence]]

- GIVEN the intentional aspen3 root/LAN/HostKeyAlias override and Git login policy
- WHEN the generated file also contains an aspen3 device
- THEN OpenSSH retains those existing explicit settings
- AND britton-gpd selects its discovered address rather than Bonsai's copied address

### Requirement: Last-good atomic refresh [r[onix.ssh.tailscale.refresh]]

The updater MUST reject unavailable, incomplete or unsafe discovery results without replacing a prior good file. Successful writes MUST atomically replace a mode-0600 user-owned file. Unchanged contents MUST avoid rewriting. A valid complete no-peers inventory MUST remove disappeared peers.

#### Scenario: Failure and removal transitions [r[onix.ssh.tailscale.refresh.transitions]]

- GIVEN a successfully generated file
- WHEN a later status command, decoding, metadata validation, or write fails
- THEN the prior file remains intact
- WHEN a subsequent complete inventory removes a peer
- THEN that peer's generated aliases disappear

### Requirement: Scoped managed scheduling [r[onix.ssh.tailscale.schedule]]

The Linux Home Manager profile MUST schedule local refresh at user-manager startup and every minute. Selected activation on Britton and Aspen3 MUST preserve unrelated configuration and MUST NOT claim a full-system switch.

#### Scenario: Source-bound selected activation [r[onix.ssh.tailscale.schedule.live]]

- GIVEN source-derived SSH config, executable and user scheduler artifacts
- WHEN the selected artifacts are activated on each machine
- THEN its own discovered aliases are available through its normal SSH config
- AND its periodic scheduler is active without activating unrelated dirty deployment work
