# Workstation Power Specification

## Purpose

Define suspend and lid behavior for interactive workstation profiles that also need to remain reachable for remote work, model downloads, or inference services.

## Requirements

### Requirement: Aspen3 idle availability

r[onix.aspen3.power.idle] `aspen3` MUST keep its interactive session from triggering automatic idle suspend while preserving non-suspend idle actions.

#### Scenario: Aspen3 omits the suspend timeout

r[onix.aspen3.power.idle.no_suspend]
- GIVEN the `aspen3` Home Manager configuration is evaluated
- WHEN the Noctalia `swayidle` user service command is rendered
- THEN the command includes the screensaver, dim, and DPMS idle actions
- AND the command does not include a `systemctl suspend` timeout

#### Scenario: Shared laptop default still suspends

r[onix.aspen3.power.idle.default_suspend]
- GIVEN a Noctalia Home Manager configuration leaves the idle suspend option at its default
- WHEN the `swayidle` user service command is rendered
- THEN the command includes a `systemctl suspend` timeout

### Requirement: Aspen3 powered lid availability

r[onix.aspen3.power.lid] `aspen3` MUST ignore lid-close sleep when docked or externally powered.

#### Scenario: External-power lid close stays awake

r[onix.aspen3.power.lid.external]
- GIVEN the `aspen3` NixOS configuration is evaluated
- WHEN logind settings are rendered
- THEN `HandleLidSwitchExternalPower` is set to `ignore`
- AND `HandleLidSwitchDocked` is set to `ignore`
- AND battery-only `HandleLidSwitch` is not overridden by this change

### Requirement: Focused power verification

r[onix.aspen3.power.verification] The change MUST include focused positive and negative/contrast validation for idle suspend rendering.

#### Scenario: Focused validation succeeds

r[onix.aspen3.power.verification.positive]
- GIVEN the updated idle module and `aspen3` override
- WHEN focused Nix evaluation checks run
- THEN `aspen3` evaluates successfully
- AND the rendered `swayidle` command matches the no-suspend expectation

#### Scenario: Contrast validation preserves the default

r[onix.aspen3.power.verification.negative]
- GIVEN the shared Noctalia idle suspend option defaults to enabled
- WHEN the focused contrast check evaluates the default option path
- THEN the default rendered `swayidle` command still contains `systemctl suspend`
