{
  config,
  ...
}:
{
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
    };

  };
  hardware = {
    graphics = {
      enable = true;
    };
    # consider an nvidia inventory tag and include xserver graphics as well
    # just make sure it's general settings and not too specific
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
  };
}
