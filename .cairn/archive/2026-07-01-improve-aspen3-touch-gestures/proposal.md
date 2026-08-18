## Why

`aspen3` is a convertible touchscreen workstation. Its Niri session already maps touch input and starts `lisgd`, but the touchscreen gesture set is sparse, hard-coded in shell, and does not cover Niri's native drag-to-workspace gesture surface. The result is a tablet mode that works but feels less deliberate than the touchpad gestures Niri already provides.

## What Changes

- Move touchscreen gesture bindings into typed Nickel data and render them into the existing `lisgd` wrapper.
- Add edge-constrained two-finger workspace gestures plus three- and four-finger touchscreen gestures for overview/workspace navigation.
- Add Niri native drag-and-drop workspace edge switching.
- Make touchpad multitouch settings explicit in the Niri config: scroll factor, tap button map, and middle-click emulation.
- Keep the existing no-touchscreen path non-fatal so non-tablet hosts still exit cleanly.

## Impact

- **Files**: `inventory/home-profiles/brittonr/base/input.ncl`, `inventory/home-profiles/brittonr/base/gestures.ncl`, `inventory/home-profiles/brittonr/noctalia/niri.nix`, `inventory/home-profiles/brittonr/noctalia/gestures.nix`
- **Testing**: Nickel export checks, Niri config validation through the Home Manager build path, focused `aspen3` system evaluation, and Cairn validation/gates.