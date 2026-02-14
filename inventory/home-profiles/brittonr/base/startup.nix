{ lib, ... }:
{
  options.startup = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      # System services spawned at compositor startup
      services = [
        "wallpaper" # swww-daemon + restore-wallpaper
        "clipboard" # wl-paste + cliphist
        "swayosd" # swayosd-server
        "polkit" # polkit-gnome authentication agent
        "network-applet" # nm-applet
        "bluetooth-applet" # blueman-applet
      ];

      # Applications spawned at startup
      apps = [
        "vesktop"
        "element-desktop"
        "sysmon" # terminal with btop
        "journalctl" # terminal with journalctl -f
      ];
    };
    description = "Applications and services to spawn at compositor startup";
  };
}
