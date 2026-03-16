{
  lib,
  config,
  pkgs,
  self,
  ...
}:
let
  builderKeyPath = config.clan.core.vars.generators.nix-builder-ssh.files."id_ed25519".path;
  iroh-ssh = pkgs.callPackage "${self}/pkgs/iroh-ssh" { };

  # Read iroh-ssh node-id from vars for ProxyCommand config
  getNodeId =
    machine:
    let
      path = self + "/vars/per-machine/${machine}/iroh-ssh/node-id/value";
    in
    if builtins.pathExists path then builtins.readFile path else null;

  aspen1NodeId = getNodeId "aspen1";
  aspen2NodeId = getNodeId "aspen2";
in
{
  # Dedicated SSH keypair for the nix daemon (root) to authenticate
  # to remote builders. Root can't access user SSH agents, so it
  # needs its own key on disk.
  clan.core.vars.generators.nix-builder-ssh = {
    files."id_ed25519" = { };
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -C "nix-builder@${config.networking.hostName}" -f "$out/id_ed25519"
    '';
  };

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
        sshKey = builderKeyPath;
        supportedFeatures = [
          "big-parallel"
        ];
      }
      # High-performance x86_64 servers via iroh-ssh
      {
        protocol = "ssh-ng";
        hostName = "iroh-aspen1";
        systems = [ "x86_64-linux" ];
        maxJobs = 16;
        speedFactor = 20;
        sshUser = "root";
        sshKey = builderKeyPath;
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
        sshKey = builderKeyPath;
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

    # System-wide ProxyCommand so the nix daemon (root) can reach
    # iroh-ssh builders. Without this, root has no SSH config for
    # these hosts and hostname resolution fails.
    extraConfig = lib.concatStrings [
      (lib.optionalString (aspen1NodeId != null) ''
        Host iroh-aspen1
          HostName aspen1
          ProxyCommand ${iroh-ssh}/bin/iroh-ssh proxy ${aspen1NodeId}
      '')
      (lib.optionalString (aspen2NodeId != null) ''
        Host iroh-aspen2
          HostName aspen2
          ProxyCommand ${iroh-ssh}/bin/iroh-ssh proxy ${aspen2NodeId}
      '')
    ];
  };
}
