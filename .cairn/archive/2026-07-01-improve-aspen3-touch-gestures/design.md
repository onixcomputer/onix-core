## Context

The `hm-laptop` profile used by `aspen3` imports the shared Noctalia/Niri Home Manager modules. Niri already supports built-in touchpad gestures and native drag-and-drop edge gestures. Touchscreen-only swipes are handled by the existing `lisgd-niri` user service, which discovers a libinput device with `touch` capability and exits successfully when none exists.

## Decisions

### 1. Extend the existing Niri and lisgd path

**Choice:** Improve the current Niri configuration and `lisgd-niri` wrapper rather than adding another gesture daemon.

**Rationale:** Niri is already the session compositor, and `lisgd` already has the required input permissions and lifecycle wiring. Keeping one gesture path avoids competing consumers for the touchscreen event device.

### 2. Put gesture policy in Nickel

**Choice:** Store touchpad and touchscreen gesture policy in the existing typed Nickel files, then render shell arguments from Nix.

**Rationale:** Nickel contracts catch malformed gesture directions, edges, activation modes, and unsupported Niri actions at evaluation time. Nix remains a thin renderer, and shell stays limited to device discovery and process execution.

### 3. Prefer edge-constrained low-finger gestures

**Choice:** Use left/right edge constraints for two-finger workspace gestures, while reserving three- and four-finger gestures for global workspace/overview actions.

**Rationale:** Edge-constraining the easiest gestures reduces conflicts with application-level two-finger panning or zooming while still making tablet navigation reachable.

## Risks / Trade-offs

- `lisgd` reads the touchscreen event device directly, so any global gesture can still intercept intended application gestures when the finger count and direction match.
- Touchscreen device names vary; the wrapper intentionally keeps capability-based discovery and exits cleanly when no touchscreen is present.
- Focused validation can prove config generation, but final feel still requires a live `aspen3` tablet-mode smoke test.