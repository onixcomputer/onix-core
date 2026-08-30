# Templates, hooks, plugins, and desktop widgets for noctalia-shell
_config:
let
  # Reload every running helix editor (hx and zen wrappers share the same
  # binary, so both appear as `hx`/`.hx-wrapped`). Helix 25.07 handles
  # SIGUSR1 by reloading its config and re-applying its theme from disk,
  # which is how Noctalia activates a live dark/light switch.
  #
  # The Noctalia built-in helix template writes the current scheme to
  # ~/.config/helix/themes/noctalia.toml before hooks run, and the helix
  # wrapper overlays that mutable directory over its immutable config, so
  # this signal refreshes in-memory editors with the new colors. Uses only
  # shell builtins; no external process tools are required.
  reloadHelix = ''
    for p in /proc/[0-9]*; do
      read -r n < "$p/comm" 2>/dev/null || continue
      case "$n" in
        hx|.hx-wrapped) kill -USR1 "''${p#/proc/}" 2>/dev/null || true ;;
      esac
    done
  '';

  niriReload = "niri msg action load-config-file";
in
{
  # -- Templates --
  # Built-in templates generate per-app config fragments whenever colors
  # change. The helix wrapper overlays ~/.config/helix/themes/ over its
  # immutable store config, so Noctalia's built-in helix template (which
  # writes ~/.config/helix/themes/noctalia.toml) applies at runtime.
  # kitty and wezterm templates write their own scheme fragments and the
  # kitty apply script reloads live instances itself.
  theme.templates = {
    enable_builtin_templates = true;
    builtin_ids = [
      "niri"
      "kitty"
      "btop"
      "helix"
      "wezterm"
    ];
    enable_community_templates = false;
    community_ids = [ ];
  };

  # -- Hooks --
  # Templates handle the theming. Hooks only tell running apps to reload:
  # niri reloads its merged config and helix refreshes its theme. They run
  # AFTER template outputs are written, so the reload reads new colors.
  # `colors_changed` fires on every palette apply (startup, mode toggle,
  # wallpaper scheme, schedule) and is the single reliable trigger.
  hooks = {
    started = "";
    colors_changed = [
      niriReload
      reloadHelix
    ];
    theme_mode_changed = "";
    wallpaper_changed = "";
    session_locked = "";
    session_unlocked = "";
  };

  # -- Plugins --
  plugins = {
    autoUpdate = false;
  };

  # -- Desktop Widgets --
  desktopWidgets = {
    enabled = false;
    gridSnap = false;
    monitorWidgets = [ ];
  };
}
