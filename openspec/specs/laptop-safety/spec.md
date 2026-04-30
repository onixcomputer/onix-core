# Laptop Safety Specification

## Purpose

This specification records requirements synced from OpenSpec change `mic92-hardening`.

## Requirements

<!-- synced from openspec change: mic92-hardening -->
## ADDED Requirements

### Requirement: auto-suspend on critical battery
Machines with the `laptop` tag SHALL have a udev rule that triggers `systemctl suspend` when battery capacity drops to 10% while discharging.

#### Scenario: laptop suspends at 10% battery
- **WHEN** the battery reaches 10% capacity and status is "Discharging"
- **THEN** the system executes `systemctl suspend`

#### Scenario: laptop does not suspend while charging
- **WHEN** the battery is at 10% but status is "Charging"
- **THEN** the udev rule does not trigger suspend

#### Scenario: desktop machines are unaffected
- **WHEN** a machine does not have the `laptop` tag
- **THEN** no low-battery udev rule is present

### Requirement: suspend-on-low-power is configurable
The battery percentage threshold SHALL be defined in a single place so it can be overridden per-machine if needed (via `mkDefault` or equivalent).

#### Scenario: machine overrides threshold to 5%
- **WHEN** a machine-specific config sets the threshold to 5
- **THEN** the udev rule triggers at 5% instead of the default 10%
