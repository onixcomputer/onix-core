{ pkgs, ... }:
{
  imports = [ ./common/gui-base.nix ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false; # Disabled for GDM compatibility - fixes first-launch crash issue
  };

  # Hyprland-specific portals
  xdg.portal = {
    wlr.enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland ];
  };

  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    hyprland-qtutils

    # Wayland utilities
    hyprpaper # Native Hyprland wallpaper utility
    swayosd # On-screen display for volume/brightness
    polkit_gnome
    wl-clip-persist

    # Input method
    fcitx5
    fcitx5-gtk
    libsForQt5.fcitx5-qt
  ];
}
