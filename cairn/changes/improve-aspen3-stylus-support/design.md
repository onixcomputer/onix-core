## Context

Niri supports tablet configuration for absolute-input devices, including output mapping, focused-output/window mapping, left-handed mode, and calibration matrices. For a convertible pen display such as `aspen3`, the safest default is still `map-to-output` for the built-in panel: the pen tip should correspond to the point under the screen rather than remapping to arbitrary windows.

## Decisions

### 1. Keep built-in output mapping as the default

**Choice:** Add typed tablet settings but leave `mapToBuiltinOutput = true` and focused mapping disabled by default.

**Rationale:** Focused-window mapping is useful for external tablets, but on a pen display it breaks direct pen-to-screen correspondence unless intentionally enabled for a special workflow.

### 2. Use typed Nickel for calibration policy

**Choice:** Add a Nickel contract that accepts either an empty calibration matrix or exactly six numeric libinput matrix entries.

**Rationale:** Empty means use libinput defaults. A six-number guard catches malformed calibration changes before Niri config validation or login-time failures.

### 3. Install workflow and diagnostic tools on aspen3

**Choice:** Add pen note/PDF apps plus low-level input diagnostics to `aspen3`'s user packages.

**Rationale:** Improved stylus support is not just compositor mapping; the machine should have an immediate app path for writing/drawing and tools to inspect Wayland/libinput events when pressure, eraser, buttons, or calibration need tuning.

## Risks / Trade-offs

- Final pressure/eraser/button behavior depends on the kernel/HID device and app support; Nix evaluation cannot prove those live device capabilities.
- `evtest` and `libinput debug-events` may require input-device permissions; the user is already in the `input` group.
- Focused-window tablet mapping remains opt-in because it is usually wrong for a direct pen display.
