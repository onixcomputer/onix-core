# SSH-reachable Meshtop Fleet Specification Delta

## Purpose

Extend the selected, authenticated two-host monitor only to additional onix-core machines with verified SSH access, without implicitly enabling all inventory machines.

## ADDED Requirements

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
