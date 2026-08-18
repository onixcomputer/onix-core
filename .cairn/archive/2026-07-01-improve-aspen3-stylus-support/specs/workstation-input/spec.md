# Workstation Input Specification

## Purpose

Define stylus behavior for interactive Niri workstation hosts, with `aspen3` as the built-in pen-display target.

## Requirements

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

### Requirement: Focused verification

r[onix.aspen3.stylus.verification] The change MUST include focused positive checks for generated configuration and negative checks that prevent false package matches.

#### Scenario: Focused configuration validation succeeds

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
