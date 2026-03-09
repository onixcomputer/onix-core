_: {
  imports = [
    # Import shared hyprland configuration
    ../../shared/hyprland/audio-utils.nix
    ../../shared/hyprland/btop.nix
    ../../shared/hyprland/clipboard.nix
    ../../shared/hyprland/cursor.nix
    ../../shared/hyprland/dunst.nix
    ../../shared/hyprland/firefox.nix
    ../../shared/hyprland/fonts.nix
    ../../shared/hyprland/helpers.nix
    ../../shared/hyprland/hyprland.nix
    ../../shared/hyprland/hyprlock.nix
    ../../shared/hyprland/keyring.nix
    ../../shared/hyprland/libreoffice.nix
    ../../shared/hyprland/media-viewers.nix
    ../../shared/hyprland/network.nix
    ../../shared/hyprland/rofi.nix
    ../../shared/hyprland/screenshot.nix
    ../../shared/hyprland/shared-config.nix
    ../../shared/hyprland/swayosd.nix
    ../../shared/hyprland/theme.nix
    ../../shared/hyprland/thunar.nix
    ../../shared/hyprland/wallpaper.nix
    ../../shared/hyprland/waybar.nix
    ../../shared/hyprland/xdg.nix

    # Override with brittonr's preferences
    ./kitty.nix
    ./theme-config.nix
  ];
}
