## Why

The default terminal on the Noctalia workstation profile is Kitty. Kitty already supports touchscreen-adjacent interactions such as high-precision scrolling, interactive scrollbars, shell-integration prompt clicks, and configurable mouse actions, but the profile only makes part of that surface explicit. On `aspen3`, tablet mode needs larger scroll targets and declared touch-scroll behavior so the terminal remains usable without reaching for a keyboard or precision pointer.

## What Changes

- Add typed terminal touch/scroll and mouse-action settings to the shared Nickel settings data.
- Enlarge Kitty scrollbar touch targets, including visible width, hover width, hitbox expansion, and minimum handle height.
- Render Kitty high-precision scroll settings explicitly: touch scroll multiplier, pixel scroll, and momentum scroll.
- Render declared Kitty mouse maps from typed data, including a right-click/long-press friendly command-output selection action that relies on Kitty shell integration.
- Keep global swipe/pinch gestures outside Kitty because Kitty exposes mouse and scroll actions, not compositor-level multitouch gesture recognition.

## Impact

- **Files**: `inventory/home-profiles/brittonr/base/settings.ncl`, `inventory/home-profiles/brittonr/noctalia/kitty.nix`, `cairn/changes/improve-terminal-touch-ergonomics/*`
- **Testing**: Nickel export checks for the shared settings data, a negative Nickel contract check for malformed mouse-map data, focused Home Manager/system evaluation for `aspen3`, and Cairn validation/gates.
