_: {
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  networking = {
    hostName = "alex-wsl";
    networkmanager.enable = true;
  };

  system.stateVersion = "25.05";
}
