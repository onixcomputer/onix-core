{ lib, ... }:
{
  # Enable distributed builds to offload compilation to faster machines
  nix = {
    distributedBuilds = lib.mkDefault true;

    settings = {
      # Allow build machines to fetch from caches directly
      builders-use-substitutes = lib.mkDefault true;
    };

    # Leviathan build machine configuration
    # Individual machines can add more build machines or override settings
    buildMachines = lib.mkDefault [
      {
        protocol = "ssh-ng";
        hostName = "leviathan.cymric-daggertooth.ts.net";
        systems = [ "x86_64-linux" ];
        maxJobs = 7;
        speedFactor = 20;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        # sshUser is set per-machine based on the user
      }
    ];
  };

  # Known host for leviathan
  programs.ssh.knownHosts = {
    leviathan = {
      hostNames = [
        "leviathan.cymric-daggertooth.ts.net"
        "leviathan"
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEtV2xoOv+N4c5sg5oBqM/Xy+aZHf+5GHOhzXKYduXG";
    };
  };
}
