## ADDED Requirements

### Requirement: Bluetooth codec preference

`aspen3` MUST declare WirePlumber Bluetooth policy that prefers high-quality A2DP codecs while preserving broadly compatible fallbacks.

#### Scenario: Preferred codecs are declared

- **WHEN** the `aspen3` NixOS configuration is evaluated
- **THEN** WirePlumber BlueZ policy includes LDAC before fallback codecs
- **AND** fallback codecs include AAC, SBC-XQ, and SBC

#### Scenario: LDAC high quality is requested

- **WHEN** a Bluetooth card negotiates LDAC on `aspen3`
- **THEN** WirePlumber policy requests the high-quality LDAC mode

### Requirement: Audio correction tooling

`aspen3` MUST provide user-facing audio correction and PipeWire diagnostics tools without forcing an unmeasured permanent DSP preset.

#### Scenario: Tools are installed

- **WHEN** the `aspen3` NixOS configuration is evaluated
- **THEN** audio correction and PipeWire graph/diagnostic tools are present in the configured packages

#### Scenario: No permanent DSP preset is forced

- **WHEN** the `aspen3` NixOS configuration is evaluated
- **THEN** no EasyEffects preset is configured to autoload globally

### Requirement: Clipping avoidance

`aspen3` MUST reduce avoidable user-space media overdrive that can clip laptop speakers.

#### Scenario: MPV overdrive is constrained

- **WHEN** the `brittonr` Home Manager configuration is evaluated for `aspen3`
- **THEN** MPV's maximum volume is lower than the shared desktop media-viewer overdrive ceiling

### Requirement: Focused validation

The change MUST include positive and negative validation evidence for the audio configuration path.

#### Scenario: Positive evaluation succeeds

- **WHEN** focused `aspen3` Nix evaluation runs after implementation
- **THEN** the configured WirePlumber, package, and MPV override values evaluate successfully

#### Scenario: Invalid codec evidence is rejected

- **WHEN** the OpenSpec requirements are reviewed
- **THEN** codec preference is required to include fallback codecs rather than only a single high-quality codec
