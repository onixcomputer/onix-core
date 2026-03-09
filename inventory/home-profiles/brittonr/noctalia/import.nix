{ inputs, ... }:
{
  imports = [
    # Noctalia home-manager module
    inputs.noctalia.homeModules.default

    # Theme support (reuse from niri)
    ../../shared/hyprland/theme.nix
    ../hyprland/theme-config.nix

    # Core utilities (keep)
    ../../shared/hyprland/audio-utils.nix
    ../../shared/hyprland/clipboard.nix
    ../../shared/hyprland/cursor.nix
    ../../shared/hyprland/fonts.nix
    ../../shared/hyprland/keyring.nix
    ../../shared/hyprland/network.nix

    # Applications (reuse)
    ./firefox.nix
    ../../shared/hyprland/thunar.nix
    ../../shared/hyprland/media-viewers.nix
    ../../shared/hyprland/btop.nix
    ../../shared/hyprland/libreoffice.nix

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
