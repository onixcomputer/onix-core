_: {
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  networking = {
    hostName = "alex-wsl";
  };

  system.stateVersion = "25.05";
}
