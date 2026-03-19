# Direct USB4/Thunderbolt host-to-host networking between paired machines.
# Uses thunderbolt_net kernel module over USB4 cable for ~40 Gbps link.
# Assign static IPs on a /30 and trust the interface for unrestricted traffic.
{ config, lib, ... }:
let
  # Static IP map — each machine gets one side of a point-to-point /30
  tbAddresses = {
    aspen1 = "10.10.10.1/30";
    aspen2 = "10.10.10.2/30";
  };

  hostname = config.networking.hostName;
  address = tbAddresses.${hostname} or null;
in
{
  config = lib.mkIf (address != null) {
    # Trust the thunderbolt interface — no firewall filtering
    networking.firewall.trustedInterfaces = [ "thunderbolt0" ];

    # Static IP via networkd match-on-driver (survives interface renaming)
    systemd.network = {
      enable = true;
      networks."50-thunderbolt" = {
        matchConfig.Driver = "thunderbolt-net";
        address = [ address ];
        networkConfig = {
          DHCP = "no";
          LinkLocalAddressing = "no";
        };
        linkConfig = {
          # Max frame size for throughput — thunderbolt_net supports 65536
          MTUBytes = "65520";
        };
      };
    };

    # Prevent NetworkManager from touching the thunderbolt interface
    networking.networkmanager.unmanaged = [ "driver:thunderbolt-net" ];
  };
}
