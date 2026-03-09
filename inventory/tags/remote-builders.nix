{ lib, ... }:
{
  # Enable distributed builds to offload compilation to faster machines
  nix = {
    distributedBuilds = lib.mkDefault true;

    settings = {
      # Allow build machines to fetch from caches directly
      builders-use-substitutes = lib.mkDefault true;
    };

    # Individual machines can add build machines via their configuration
    buildMachines = lib.mkDefault [ ];
  };
}
