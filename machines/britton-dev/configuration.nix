_: {
  networking = {
    hostName = "britton-dev";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  system.stateVersion = "24.11";
}
