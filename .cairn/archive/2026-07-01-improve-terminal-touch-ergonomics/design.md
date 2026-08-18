## Context

`inventory/home-profiles/brittonr/base/apps.ncl` declares Kitty as the default terminal. `inventory/home-profiles/brittonr/noctalia/kitty.nix` already enables Kitty shell integration, URL detection, and an always-visible interactive scrollbar. The remaining terminal touch ergonomics are implicit defaults or hard-coded renderer values, and there is no typed mouse-map data for touch/stylus-friendly terminal actions.

Kitty's local 0.47.x documentation shows the relevant native surfaces:

- `touch_scroll_multiplier`, `pixel_scroll`, and `momentum_scroll` tune high-precision finger scrolling on Wayland.
- `scrollbar_width`, `scrollbar_hover_width`, `scrollbar_hitbox_expansion`, and `scrollbar_min_handle_height` control the scroll target.
- `mouse_map` maps mouse/touch-emulated button events to actions such as `mouse_select_command_output`.
- Shell integration is required for prompt-aware click behavior and command-output actions.

## Decisions

### 1. Use Kitty's native touch-scroll and mouse-action surface

**Choice:** Improve the existing Kitty profile instead of switching terminal emulators or adding a terminal-specific gesture daemon.

**Rationale:** Kitty is already the default terminal and exposes the scroll/mouse features needed for terminal-local touch ergonomics. Compositor-wide gestures belong in the existing Niri/`lisgd` path; Kitty should remain responsible only for terminal-local scrollbars, scrolling, links, selections, and command-output navigation.

### 2. Keep policy in Nickel and rendering in Nix

**Choice:** Add typed Nickel fields for terminal scroll tuning, scrollbar hitbox sizing, and mouse maps. Render them in the Kitty Home Manager module.

**Rationale:** Nickel contracts reject malformed button names, event types, mode values, and empty action strings before they reach Kitty. Nix remains a thin renderer and does not embed gesture policy.

### 3. Prefer conservative terminal-local behavior

**Choice:** Keep Kitty's default smooth scrolling concepts, make them explicit, gently adjust the high-precision touch scroll multiplier, and make right-click/long-press select command output rather than replacing global gestures.

**Rationale:** Large behavioral changes inside terminal applications can conflict with TUIs that grab the mouse. The change improves reachable terminal affordances while preserving Kitty's existing keyboard bindings and compositor gestures.

## Risks / Trade-offs

- A right-click or touch long-press mapping changes bare right-click behavior from extending a selection to selecting the clicked command output. Shift-right-click remains available for selection extension through Kitty's default grabbed mapping.
- `mouse_select_command_output` depends on shell integration and command markers. Without shell integration markers it is harmless but less useful.
- Touch feel still requires live `aspen3` testing after deployment because scroll velocity and long-press synthesis vary by hardware and compositor.
