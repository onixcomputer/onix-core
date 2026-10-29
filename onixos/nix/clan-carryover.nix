# Machine defaults that clan-core adds to every NixOS machine and onix-core
# relies on, carried over unchanged for the OnixOS build. Values are copied
# from clan-core 86d72f39 (the rev in flake.lock) with
# enableRecommendedDefaults = true and meta.domain unset:
#   nixosModules/clanCore/defaults.nix, nix-settings.nix, networking.nix,
#   zfs.nix and state-version/default.nix.
# Clan's service modules (sshd, users, borgbackup) are ported separately as
# Nickel modules in onixos/services.
{ self, machineName }:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    {
      environment.ldso32 = null;
      environment.systemPackages = [ pkgs.nixos-facter ];

      nix = {
        daemonCPUSchedPolicy = lib.mkDefault "batch";
        daemonIOSchedClass = lib.mkDefault "idle";
        daemonIOSchedPriority = lib.mkDefault 7;
      };
    }
  ];

  documentation.doc.enable = lib.mkDefault false;
  documentation.info.enable = lib.mkDefault false;

  environment.systemPackages = [
    pkgs.dnsutils
    pkgs.tcpdump
    pkgs.curl
    pkgs.jq
    pkgs.htop
    pkgs.gitMinimal
  ];

  nix.settings = {
    connect-timeout = 5;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    log-lines = lib.mkDefault 25;
    max-free = lib.mkDefault (3000 * 1024 * 1024);
    min-free = lib.mkDefault (512 * 1024 * 1024);
    builders-use-substitutes = true;
  };

  networking = {
    useHostResolvConf = false;
    firewall.allowPing = true;
    firewall.allowedUDPPorts = [ 5353 ];
    useNetworkd = lib.mkDefault true;
    # Clan's meta.domain default; machines resolve as <name>.clan.
    domain = lib.mkDefault "clan";
    # The installer and nixos-anywhere hostId, so ZFS pools import cleanly.
    hostId = lib.mkDefault "8425e349";
  };
  systemd = {
    services.NetworkManager-wait-online.enable = false;
    network = {
      wait-online.enable = false;
      networks."99-ethernet-default-dhcp".networkConfig.MulticastDNS = lib.mkDefault true;
      networks."99-wireless-client-dhcp".networkConfig.MulticastDNS = lib.mkDefault true;
    };
  };

  boot.zfs.forceImportRoot = lib.mkDefault false;
  services.zfs = lib.mkIf config.boot.zfs.enabled {
    autoSnapshot.enable = true;
    autoSnapshot.monthly = lib.mkDefault 1;
    autoScrub.enable = true;
  };

  # Clan's state-version generator stored the first release this machine
  # ran; keep reading that record until the machine leaves Clan.
  system.stateVersion = lib.mkDefault (
    lib.removeSuffix "\n" (
      builtins.readFile "${self}/vars/per-machine/${machineName}/state-version/version/value"
    )
  );
}
