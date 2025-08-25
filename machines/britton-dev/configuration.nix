_: {
  networking = {
    hostName = "britton-dev";
  };

  time.timeZone = "America/New_York";

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
