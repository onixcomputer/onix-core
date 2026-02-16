{ inputs, ... }:
{
  imports = [
    # Noctalia home-manager module
    inputs.noctalia.homeModules.default

    # Theme support (reuse from niri)
    ../../alex/hyprland/theme.nix
    ../hyprland/theme-config.nix

    # Core utilities (keep)
    ../../alex/hyprland/audio-utils.nix
    ../../alex/hyprland/clipboard.nix
    ../../alex/hyprland/cursor.nix
    ../../alex/hyprland/fonts.nix
    ../../alex/hyprland/keyring.nix
    ../../alex/hyprland/network.nix

    # Applications (reuse)
    ./firefox.nix
    ../../alex/hyprland/thunar.nix
    ../../alex/hyprland/media-viewers.nix
    ../../alex/hyprland/btop.nix
    ../../alex/hyprland/libreoffice.nix

    # Noctalia-specific
    ./noctalia-config.nix
    ./niri.nix
    ./screenshot.nix
    ./darkman.nix
    ./gestures.nix
    ../hyprland/kitty.nix

    # Replaced by Noctalia (not imported):
    # - waybar.nix (Noctalia bar)
    # - mako.nix (Noctalia notifications)
    # - fuzzel.nix (Noctalia launcher)
    # - fuzzel-scripts.nix (Noctalia features replace most)
    # - swayosd.nix (Noctalia OSD)
    # - wallpaper.nix (Noctalia built-in wallpaper)
  ];
}
