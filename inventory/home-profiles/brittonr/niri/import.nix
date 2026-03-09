_: {
  imports = [
    # Theme support (required by kitty and other apps)
    ../../shared/hyprland/theme.nix
    ../hyprland/theme-config.nix

    # Core system utilities
    ../../shared/hyprland/audio-utils.nix
    ../../shared/hyprland/clipboard.nix
    ../../shared/hyprland/cursor.nix
    ./mako.nix
    ../../shared/hyprland/fonts.nix
    ../../shared/hyprland/keyring.nix
    ../../shared/hyprland/network.nix
    ./screenshot.nix
    ../../shared/hyprland/swayosd.nix
    ../../shared/hyprland/wallpaper.nix
    # ../../shared/hyprland/xdg.nix # Commented out - using brittonr's own xdg.nix from dev profile

    # Applications
    ./firefox.nix
    ../../shared/hyprland/thunar.nix
    ../../shared/hyprland/media-viewers.nix
    ../../shared/hyprland/btop.nix
    ../../shared/hyprland/libreoffice.nix

    # Niri specific
    ./niri.nix
    ./waybar.nix
    ./fuzzel.nix
    ./fuzzel-scripts.nix
    ./darkman.nix
    ./gestures.nix
    ../hyprland/kitty.nix
  ];
}
