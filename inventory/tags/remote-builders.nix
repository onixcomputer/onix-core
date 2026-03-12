{ lib, ... }:
{
  # Enable distributed builds to offload compilation to faster machines
  nix = {
    distributedBuilds = lib.mkDefault true;

    settings = {
      # Allow build machines to fetch from caches directly
      builders-use-substitutes = lib.mkDefault true;
    };

    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "britton-air.local";
        systems = [
          "aarch64-darwin"
          "aarch64-linux"
        ];
        maxJobs = 10;
        speedFactor = 12;
        sshUser = "brittonr";
        supportedFeatures = [ "big-parallel" ];
      }
    ];
  };

  programs.ssh = {
    knownHosts.britton-air = {
      hostNames = [
        "britton-air"
        "britton-air.local"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYzE7FHHUK6h6wLFyV+dX3SubV80IA7b1+Pp0cIxgf";
    };
  };
}
