{ lib, pkgs, ... }:
{
  # TUI-based greeter with tuigreet
  # Session command is configured per-machine in homeManagerOptions or machine config
  services.greetd = {
    enable = lib.mkDefault true;
    settings = {
      default_session = {
        # Default to Hyprland, override per-machine for niri-session etc
        command = lib.mkDefault "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # Plymouth boot splash — themed animation during boot instead of
  # scrolling kernel log text. Hides the wall of [ OK ] messages.
  # Kernel params silenced so Plymouth isn't interrupted by text.
  boot = {
    plymouth = {
      enable = lib.mkDefault true;
      theme = lib.mkDefault "bgrt"; # OEM logo with spinner (clean, fast)
    };
    consoleLogLevel = lib.mkDefault 0;
    initrd.verbose = lib.mkDefault false;
    kernelParams = lib.mkDefault [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };

  # Common PAM services for desktop login
  security.pam.services = {
    login.enableGnomeKeyring = lib.mkDefault true;
    greetd.enableGnomeKeyring = lib.mkDefault true;
    hyprlock = { };
  };

  # Gnome keyring for SSH agent and secrets
  services.gnome.gnome-keyring.enable = lib.mkDefault true;
}
