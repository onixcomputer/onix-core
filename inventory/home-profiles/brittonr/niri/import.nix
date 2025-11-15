_: {
  imports = [
    # Theme support (required by kitty and other apps)
    ../../alex/hyprland/theme.nix
    ../hyprland/theme-config.nix

    # Core system utilities
    ../../alex/hyprland/audio-utils.nix
    ../../alex/hyprland/clipboard.nix
    ../../alex/hyprland/cursor.nix
    ../../alex/hyprland/dunst.nix
    ../../alex/hyprland/fonts.nix
    ../../alex/hyprland/keyring.nix
    ../../alex/hyprland/network.nix
    ../../alex/hyprland/screenshot.nix
    ../../alex/hyprland/swayosd.nix
    ../../alex/hyprland/wallpaper.nix
    # ../../alex/hyprland/xdg.nix # Commented out - using brittonr's own xdg.nix from dev profile

    # Applications
    ../../alex/hyprland/firefox.nix
    ../../alex/hyprland/thunar.nix
    ../../alex/hyprland/media-viewers.nix
    ../../alex/hyprland/btop.nix
    ../../alex/hyprland/libreoffice.nix

    # Niri specific
    ./niri.nix
    ./waybar.nix
    ./fuzzel.nix
    ./fuzzel-scripts.nix
    ./darkman.nix
    ../hyprland/kitty.nix
  ];
}
