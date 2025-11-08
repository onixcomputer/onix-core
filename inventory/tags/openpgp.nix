{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    gnupg # GPG for OpenPGP operations
    pcsclite # PC/SC daemon for smart card communication
    ccid # CCID driver for USB smart cards
    pcsc-tools # Tools like pcsc_scan for debugging
    pinentry-gtk2 # PIN entry dialog (or pinentry-qt, pinentry-curses)
  ];
  # Required services
  services.pcscd.enable = true; # Enable PC/SC daemon service

  # Optional: GPG agent configuration
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true; # Optional: use GPG key for SSH
    pinentryPackage = pkgs.pinentry-gtk2; # Or pinentry-qt, pinentry-curses
  };

  # Optional: udev rules for direct USB access (if needed)
  services.udev.packages = [ pkgs.pcsclite ];
}
