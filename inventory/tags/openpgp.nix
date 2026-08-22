{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    gnupg # GPG for OpenPGP operations
    pcsclite # PC/SC daemon for smart card communication
    ccid # CCID driver for USB smart cards
    pcsc-tools # Tools like pcsc_scan for debugging
    # pinentry-gtk2 was removed from nixpkgs 2026-08-12 (GTK2 deprecation).
    # These machines run Niri + gnome-keyring, so use the GNOME/GTK3 flavor.
    pinentry-gnome3 # PIN entry dialog (or pinentry-qt, pinentry-curses)
  ];
  # Required services
  services.pcscd.enable = true; # Enable PC/SC daemon service

  # Optional: GPG agent configuration
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true; # Optional: use GPG key for SSH
    pinentryPackage = pkgs.pinentry-gnome3; # Or pinentry-qt, pinentry-curses
  };

  # Optional: udev rules for direct USB access (if needed)
  services.udev.packages = [ pkgs.pcsclite ];
}
