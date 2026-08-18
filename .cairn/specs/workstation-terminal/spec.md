# Workstation Terminal Specification

## Purpose

Define terminal emulator touch, scroll, and mouse-action ergonomics for interactive Wayland workstation profiles that use Kitty as the default terminal.

## Requirements

### Requirement: Kitty touch-scroll ergonomics

r[onix.workstation.terminal.touch.scroll] The workstation terminal configuration MUST render explicit Kitty high-precision scroll settings for touchpad and touchscreen use.

#### Scenario: High-precision scroll settings render

r[onix.workstation.terminal.touch.scroll.render]
- GIVEN the Noctalia Kitty Home Manager configuration is generated
- WHEN terminal scroll settings are rendered
- THEN the config includes a declared `touch_scroll_multiplier`
- AND the config includes a declared `pixel_scroll`
- AND the config includes a declared `momentum_scroll`

### Requirement: Touch-friendly scrollbar targets

r[onix.workstation.terminal.touch.scrollbar] The workstation terminal configuration MUST render a visible and interactive Kitty scrollbar with touch-friendly hit targets.

#### Scenario: Scrollbar target settings render

r[onix.workstation.terminal.touch.scrollbar.render]
- GIVEN the Noctalia Kitty Home Manager configuration is generated
- WHEN the scrollbar settings are rendered
- THEN the config includes declared visible and hover widths
- AND the config includes a declared hitbox expansion
- AND the config includes a declared minimum handle height
- AND the scrollbar remains interactive and jump-on-click enabled

### Requirement: Terminal mouse actions

r[onix.workstation.terminal.touch.mouse_maps] The workstation terminal configuration MUST render terminal-local Kitty mouse actions from typed settings data.

#### Scenario: Typed mouse maps render

r[onix.workstation.terminal.touch.mouse_maps.render]
- GIVEN typed terminal mouse-map settings are evaluated
- WHEN the Kitty extra configuration is rendered
- THEN each enabled mouse map is emitted as a `mouse_map` line
- AND the default configuration includes a right-click/long-press friendly command-output selection action

#### Scenario: Malformed mouse maps are rejected

r[onix.workstation.terminal.touch.mouse_maps.reject_malformed]
- GIVEN a terminal mouse-map setting has an unsupported event type or an empty action
- WHEN the typed settings data is exported
- THEN Nickel rejects the configuration before Home Manager renders Kitty config

### Requirement: Focused verification

r[onix.workstation.terminal.touch.verification] The change MUST include focused positive validation for generated terminal configuration and negative validation for malformed typed mouse-map data.

#### Scenario: Focused configuration validation succeeds

r[onix.workstation.terminal.touch.verification.positive]
- GIVEN the updated typed settings data and Kitty renderer
- WHEN Nickel export checks and focused `aspen3` system evaluation run
- THEN the checks succeed
- AND Home Manager evaluates the Kitty configuration using the typed terminal data

#### Scenario: Negative typed-data validation fails closed

r[onix.workstation.terminal.touch.verification.negative]
- GIVEN malformed terminal mouse-map data is introduced in a temporary validation fixture
- WHEN Nickel export is run on that fixture
- THEN the export fails
- AND the tracked settings file remains unchanged
