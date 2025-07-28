_: {
  networking = {
    hostName = "alex-mu";
    networkmanager.enable = true;
  };

  time.timeZone = "America/New_York";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  system.stateVersion = "25.05";
}
