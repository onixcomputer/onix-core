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

  # Common PAM services for desktop login
  security.pam.services = {
    login.enableGnomeKeyring = lib.mkDefault true;
    greetd.enableGnomeKeyring = lib.mkDefault true;
    hyprlock = { };
  };

  # Gnome keyring for SSH agent and secrets
  services.gnome.gnome-keyring.enable = lib.mkDefault true;
}
