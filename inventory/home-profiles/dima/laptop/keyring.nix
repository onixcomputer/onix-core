{ pkgs, ... }:
{
  services.gnome-keyring = {
    enable = true;
    components = [
      "pkcs11"
      "secrets"
      "ssh"
    ];
  };

  home.packages = with pkgs; [
    seahorse # GUI for managing keys
    gcr # For SSH askpass dialog
    libsecret # Secret service API for Element
  ];
}
