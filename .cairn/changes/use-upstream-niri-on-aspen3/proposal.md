# Use upstream Niri on Aspen3

## Why

The compositor input still points to `brittonr/niri`, and the Home Manager package is patched to replace that fork's incompatible `libdisplay-info` dependency. Aspen3's greeter launches `niri-session` through a user profile, which can lag behind the selected system generation.

## What Changes

- Lock `niri-wm/niri` directly and use its package for the compositor, gestures, and sticky-window helpers. Delete the fork-specific package override.
- Launch Aspen3's `niri-session` from the same pinned upstream input used by its Home Manager service.
- Drop KDL options and keybindings that exist only in the fork, so the rendered configuration validates with upstream Niri.

## Impact

- **Scope**: The shared Noctalia profile moves every Niri host to upstream; Aspen3's greeter path also becomes explicit.
- **Behavior change**: The fork's zero-gap overview, spatial column-tile focus, and fit-columns/grid actions have no upstream equivalents. Their settings and two bindings are removed, not silently rebound to different behavior.
- **Rollout**: Aspen3's NixOS/Home Manager generation is deployed. Greetd was restarted onto the pinned upstream launcher and the stale fork session was stopped; the next console login starts upstream Niri. Other hosts take the shared profile change when they are activated.
- **Verification**: The upstream executable and Aspen3 wrapper were built, the generated and activated KDL validated, and the existing touchpad check passed. The deployed profile reports the upstream commit; no interactive graphical login was performed.
