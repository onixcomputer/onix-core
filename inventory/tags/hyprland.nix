{ pkgs, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = false; # Disabled for GDM compatibility - fixes first-launch crash issue
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-hyprland ];
  };

  security.polkit.enable = true;

  environment.systemPackages = with pkgs; [
    hypridle
    hyprlock
    hyprland-qtutils
    hyprpaper # Native Hyprland wallpaper utility
    swayosd # On-screen display for volume/brightness
    polkit_gnome
    wl-clip-persist

    # Input method
    fcitx5
    fcitx5-gtk
    libsForQt5.fcitx5-qt
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  fonts.fontconfig = {
    enable = true;
    antialias = true;
    hinting = {
      enable = true;
      style = "slight";
    };
    subpixel.lcdfilter = "default";
    useEmbeddedBitmaps = true;
  };
}
