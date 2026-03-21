{ inputs, ... }:
{
  imports = [
    # Noctalia home-manager module
    inputs.noctalia.homeModules.default

    # Theme support
    ../../shared/desktop/theme.nix
    ./theme-config.nix

    # Core utilities
    ../../shared/desktop/audio-utils.nix
    ../../shared/desktop/clipboard.nix
    ../../shared/desktop/cursor.nix
    ../../shared/desktop/fonts.nix
    ../../shared/desktop/keyring.nix
    ../../shared/desktop/network.nix

    # Applications
    ./firefox.nix
    ../../shared/desktop/thunar.nix
    ../../shared/desktop/media-viewers.nix
    ../../shared/desktop/btop.nix
    ../../shared/desktop/libreoffice.nix
    ../../shared/desktop/screen-recording.nix
    ../../shared/desktop/emoji-picker.nix

    # Noctalia-specific
    ./noctalia-config.nix
    ./niri.nix
    ./screenshot.nix
    ./darkman.nix
    ./gestures.nix
    ./sticky-windows.nix
    ./kitty.nix
    ./wezterm.nix
  ];
}
