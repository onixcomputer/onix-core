{ pkgs, ... }:
{
  # CUPS printing
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint # Wide printer support
      hplip # HP printers
    ];
    browsing = true;
    defaultShared = false;
  };

  # Avahi for network printer discovery (mDNS already enabled in nixos.nix)
  services.avahi = {
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # Scanner support
  hardware.sane = {
    enable = true;
    extraBackends = with pkgs; [
      sane-airscan # Driverless scanning (eSCL / WSD)
    ];
  };

  environment.systemPackages = with pkgs; [
    system-config-printer # GUI printer configuration
    simple-scan # Scanner GUI
  ];
}
