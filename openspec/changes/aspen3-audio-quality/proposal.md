## Why

`aspen3` uses the generic PipeWire audio tag today, but its laptop speakers, Bluetooth headphones, and media-player volume ceilings are not tuned for clean everyday listening. We need low-risk declarative audio improvements that improve perceived quality without destabilizing the laptop or requiring live host mutation during evaluation.

## What Changes

- Add an `aspen3`-scoped declarative audio quality profile for PipeWire/WirePlumber.
- Apply Bluetooth codec preferences from the existing Home Manager audio source of truth so LDAC-capable devices prefer higher-quality codecs while keeping safe fallbacks.
- Add a user-facing DSP package path for speaker/headphone correction.
- Reduce obvious software overdrive paths that can clip laptop speakers.
- Add lightweight diagnostics packages so future audio issues can be inspected from the configured system.

## Capabilities

### New Capabilities

- `aspen3-audio-quality`: Covers declarative `aspen3` audio quality defaults, Bluetooth codec preference, clipping avoidance, DSP tooling, and validation/diagnostics support.

### Modified Capabilities

None.

## Impact

- Affects `machines/aspen3/configuration.nix` and shared/user audio/media Home Manager settings.
- Adds runtime packages for audio tuning and diagnostics.
- No public APIs or network services change.
- Validation should include Nickel export/evaluation where audio data changes, Nix formatting, and focused NixOS/Home Manager evaluation for `aspen3` where available.
