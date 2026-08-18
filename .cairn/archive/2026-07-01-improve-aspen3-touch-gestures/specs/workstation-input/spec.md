# Workstation Input Specification

## Purpose

Define touchpad and touchscreen gesture behavior for interactive Niri workstation hosts, with `aspen3` as the target convertible workstation.

## Requirements

### Requirement: Niri multitouch ergonomics

r[onix.aspen3.touch.niri] The system MUST render explicit Niri touchpad multitouch settings and native drag-and-drop workspace switching for `aspen3`'s interactive session.

#### Scenario: Touchpad multitouch settings render

r[onix.aspen3.touch.niri.touchpad]
- GIVEN the `aspen3` Home Manager Niri configuration is generated
- WHEN the `input.touchpad` block is rendered
- THEN the config includes a declared `scroll-factor`
- AND the config includes a declared `tap-button-map`
- AND the config includes middle-click emulation when enabled in typed input data

#### Scenario: Overview drag can switch workspaces

r[onix.aspen3.touch.niri.dnd_workspace]
- GIVEN the `aspen3` Niri configuration is generated
- WHEN the `gestures` block is rendered
- THEN the config includes `dnd-edge-workspace-switch`
- AND its trigger height, delay, and maximum speed come from typed gesture data

### Requirement: Touchscreen gesture daemon

r[onix.aspen3.touch.lisgd] The system MUST manage touchscreen gestures through the existing `lisgd-niri` user service using typed gesture data.

#### Scenario: Multi-finger touchscreen gestures are configured

r[onix.aspen3.touch.lisgd.multifinger]
- GIVEN typed `lisgd` gesture bindings are evaluated
- WHEN the `lisgd-niri` wrapper is rendered
- THEN the wrapper includes edge-constrained two-finger workspace gestures
- AND the wrapper includes three-finger workspace gestures
- AND the wrapper includes four-finger overview gestures

#### Scenario: Hosts without touchscreens exit cleanly

r[onix.aspen3.touch.lisgd.no_touch]
- GIVEN a host has no libinput device with touchscreen capability
- WHEN the `lisgd-niri` wrapper starts
- THEN it logs that no touchscreen was found
- AND it exits successfully without forcing the user service into a restart loop

### Requirement: Focused verification

r[onix.aspen3.touch.verification] The change MUST include focused positive validation for the generated configuration and a negative guard for malformed gesture handler invocation.

#### Scenario: Focused configuration validation succeeds

r[onix.aspen3.touch.verification.positive]
- GIVEN the updated typed input and gesture data
- WHEN Nickel export checks and focused `aspen3` system evaluation run
- THEN the checks succeed
- AND Niri config validation is exercised by the Home Manager build path

#### Scenario: Gesture handler rejects malformed invocation

r[onix.aspen3.touch.verification.negative]
- GIVEN the generated gesture handler is invoked without the required action and label arguments
- WHEN the handler starts
- THEN it exits with an error
- AND it prints usage instead of sending an incomplete Niri action
