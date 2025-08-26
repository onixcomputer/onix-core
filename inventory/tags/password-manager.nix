{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # Bitwarden clients for Vaultwarden
    bitwarden-desktop
    bitwarden-cli

    # YubiKey management tools
    yubikey-manager # CLI tool (ykman command)
    yubioath-flutter # GUI for YubiKey
    yubikey-personalization # Additional YubiKey tools
    yubico-pam # System login with YubiKey
  ];

  # Enable smart card daemon
  services.pcscd.enable = true;

  # Add udev rules for YubiKey (non-root access)
  services.udev.packages = [
    pkgs.yubikey-personalization
  ];
}
