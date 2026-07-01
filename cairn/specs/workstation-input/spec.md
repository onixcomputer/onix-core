# Workstation Input Specification

## Purpose

Define touchpad, touchscreen, and stylus behavior for interactive Niri workstation hosts, with `aspen3` as the convertible touchscreen and built-in pen-display target.

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

### Requirement: Touch input focused verification

r[onix.aspen3.touch.verification] The change MUST include focused positive validation for the generated configuration and a negative guard for malformed gesture handler invocation.

#### Scenario: Focused touch configuration validation succeeds

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

### Requirement: Niri stylus mapping

r[onix.aspen3.stylus.niri] The system MUST render typed tablet/stylus settings into the Niri input configuration for `aspen3`.

#### Scenario: Built-in pen display mapping is preserved

r[onix.aspen3.stylus.niri.output]
- GIVEN the `aspen3` Niri configuration is generated
- WHEN the `input.tablet` block is rendered
- THEN tablet input maps to the built-in output by default
- AND focused-output mapping is available only when enabled in typed input data
- AND focused-window mapping is available only when enabled in typed input data

#### Scenario: Calibration is guarded

r[onix.aspen3.stylus.niri.calibration]
- GIVEN typed tablet input data is evaluated
- WHEN the calibration matrix is empty
- THEN the Niri config omits `calibration-matrix` and uses libinput defaults
- AND when a calibration matrix is provided it must contain exactly six numeric entries

### Requirement: Stylus workflow tools

r[onix.aspen3.stylus.tools] The system MUST install stylus workflow and diagnostic tools for the `aspen3` user profile.

#### Scenario: Pen apps are present

r[onix.aspen3.stylus.tools.apps]
- GIVEN `aspen3` Home Manager packages are evaluated
- WHEN package names are inspected
- THEN `rnote` is present for handwriting and sketching
- AND `xournalpp` is present for PDF annotation and note-taking

#### Scenario: Input diagnostics are present

r[onix.aspen3.stylus.tools.diagnostics]
- GIVEN `aspen3` Home Manager packages are evaluated
- WHEN package names are inspected
- THEN `libinput`, `libwacom`, `wev`, and `evtest` are present for live stylus/input inspection

### Requirement: Stylus focused verification

r[onix.aspen3.stylus.verification] The change MUST include focused positive checks for generated configuration and negative checks that prevent false package matches.

#### Scenario: Focused stylus configuration validation succeeds

r[onix.aspen3.stylus.verification.positive]
- GIVEN the updated typed tablet data and aspen3 package list
- WHEN Nickel export checks and focused `aspen3` system evaluation run
- THEN the checks succeed
- AND Niri config validation is exercised by the Home Manager build path

#### Scenario: Bogus stylus package match fails

r[onix.aspen3.stylus.verification.negative]
- GIVEN the evaluated `aspen3` Home Manager package names
- WHEN checking for a package name that was not declared, such as `stylus-bogus`
- THEN the check returns false
