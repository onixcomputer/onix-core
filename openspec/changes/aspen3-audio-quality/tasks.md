## 1. Baseline and configuration

- [x] 1.1 Run a focused baseline `aspen3` Nix evaluation before changing audio configuration.
- [x] 1.2 Add `aspen3` WirePlumber Bluetooth codec preference and LDAC high-quality policy.
- [x] 1.3 Add audio correction and PipeWire diagnostics packages for `aspen3`.
- [x] 1.4 Add an `aspen3`-scoped Home Manager MPV volume ceiling override.

## 2. Validation

- [x] 2.1 Run formatting for changed Nix files.
- [x] 2.2 Run positive focused `aspen3` Nix evaluations for WirePlumber, packages, and MPV override values.
- [x] 2.3 Run a negative/static validation that rejects Bluetooth codec policy without fallback codecs.
- [x] 2.4 Run OpenSpec status for `aspen3-audio-quality` and confirm tasks are complete.
