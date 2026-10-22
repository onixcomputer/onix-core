# Leviathan Meshtop enrollment specification delta

## Purpose

Add one explicitly authorized external builder to the already-paired desktop monitor without expanding Meshtop's authority or the onix-core machine inventory.

## ADDED Requirements

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
