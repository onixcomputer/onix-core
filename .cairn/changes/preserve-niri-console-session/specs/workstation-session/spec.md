# Workstation Session Specification Delta

## Purpose

Niri uses the console login session to control its display and input devices.

## ADDED Requirements

### Requirement: Preserve the console session context

r[onix.niri.session.context] The Niri launcher MUST preserve the console session ID, seat, and terminal number through the systemd and D-Bus environment imports. It MUST set the session type to Wayland and clear the console variables from systemd at logout.

#### Scenario: An SSH login exists before the console login

r[onix.niri.session.context.console]
- GIVEN an SSH login precedes the console login
- WHEN greetd starts the Niri launcher
- THEN the Niri service receives the console `XDG_SESSION_ID`, `XDG_SEAT`, and `XDG_VTNR`
- AND the service receives `XDG_SESSION_TYPE=wayland`

#### Scenario: The console session ends

r[onix.niri.session.context.cleanup]
- GIVEN the launcher imported console session variables
- WHEN the Niri service ends
- THEN the launcher clears those variables from the systemd environment

### Requirement: Test the launcher environment contract

r[onix.niri.session.regression] The Niri package MUST test two distinct console session IDs and reject a second launch when Niri is active. The regression tests MUST reject the original launcher that omits the console variables.

#### Scenario: The package tests the launcher

r[onix.niri.session.regression.tests]
- GIVEN the corrected package and the original launcher fixture
- WHEN the launcher tests run
- THEN the corrected launcher passes both session cases and the active-session guard
- AND the original launcher fails because its variable list omits `XDG_SESSION_ID`

### Requirement: Limit and check the deployed correction

r[onix.niri.session.deployment] The deployment MUST preserve the compositor binary and unrelated system services. Runtime evidence MUST show an active console session and current modes for both connected displays on `aspen3`.

#### Scenario: The corrected session runs on aspen3

r[onix.niri.session.deployment.outputs]
- GIVEN the corrected launcher is installed on `aspen3`
- WHEN Niri runs in the console session
- THEN the console session is active with type `wayland`
- AND the Niri outputs `eDP-1` and `HDMI-A-1` have current modes
