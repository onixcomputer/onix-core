# Meshtop hardware model names specification delta

## Purpose

Identify the hardware behind paired CPU and supported GPU counters without changing the agent's authority or counter scope.

## ADDED Requirements

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
