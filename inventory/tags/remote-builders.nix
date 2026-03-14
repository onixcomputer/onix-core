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
      # High-performance x86_64 servers via iroh-ssh
      {
        protocol = "ssh-ng";
        hostName = "iroh-aspen1";
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 20;
        sshUser = "root";
        supportedFeatures = [
          "nixos-test"
          "big-parallel"
          "kvm"
        ];
      }
      {
        protocol = "ssh-ng";
        hostName = "iroh-aspen2";
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 20;
        sshUser = "root";
        supportedFeatures = [
          "nixos-test"
          "big-parallel"
          "kvm"
        ];
      }
    ];
  };

  programs.ssh = {
    knownHosts = {
      britton-air = {
        hostNames = [
          "britton-air"
          "britton-air.local"
        ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJWYzE7FHHUK6h6wLFyV+dX3SubV80IA7b1+Pp0cIxgf";
      };
      iroh-aspen1 = {
        hostNames = [ "iroh-aspen1" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ9UKgEetvZQOzF7N0a9VIy9xV+tKFCibumRQPGGJtLJ";
      };
      iroh-aspen2 = {
        hostNames = [ "iroh-aspen2" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtI+OcaTRozgRVulDWgL8d8eICp6oh1Ola5N46uUt/r";
      };
    };
  };
}
