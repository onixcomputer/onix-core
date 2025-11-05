_: {
  imports = [
    # Import all of alex's hyprland configuration
    ../../alex/hyprland/audio-utils.nix
    ../../alex/hyprland/btop.nix
    ../../alex/hyprland/clipboard.nix
    ../../alex/hyprland/cursor.nix
    ../../alex/hyprland/dunst.nix
    ../../alex/hyprland/firefox.nix
    ../../alex/hyprland/fonts.nix
    ../../alex/hyprland/helpers.nix
    ../../alex/hyprland/hyprland.nix
    ../../alex/hyprland/hyprlock.nix
    ../../alex/hyprland/keyring.nix
    ../../alex/hyprland/kitty.nix
    ../../alex/hyprland/media-viewers.nix
    ../../alex/hyprland/network.nix
    ../../alex/hyprland/rofi.nix
    ../../alex/hyprland/screenshot.nix
    ../../alex/hyprland/swayosd.nix
    ../../alex/hyprland/theme.nix
    ../../alex/hyprland/thunar.nix
    ../../alex/hyprland/wallpaper.nix
    ../../alex/hyprland/waybar.nix
    ../../alex/hyprland/xdg.nix

    # Override with dima's theme preferences
    ./theme-config.nix
  ];
}
