## Why

`aspen3` has a built-in pen-capable display, but the current Niri config only maps generic tablet input to the built-in output and does not expose stylus calibration/focus options or install pen-oriented user tools. That makes basic pen input possible but leaves troubleshooting, note-taking, PDF annotation, and future calibration changes manual.

## What Changes

- Extend typed input data with a `tablet` section for stylus mapping, left-handed mode, and optional libinput calibration matrices.
- Render those tablet settings into the Niri `input.tablet` block while preserving the default built-in display mapping for pen-display behavior.
- Add aspen3 user packages for pen workflows and diagnostics: RNote, Xournal++, libinput/libwacom tooling, `wev`, and `evtest`.

## Impact

- **Files**: `inventory/home-profiles/brittonr/base/input.ncl`, `inventory/home-profiles/brittonr/noctalia/niri.nix`, `machines/aspen3/configuration.nix`
- **Testing**: Nickel export checks, focused `aspen3` system build so Niri config validation runs, package-list positive/negative checks, and Cairn validation/gates.
