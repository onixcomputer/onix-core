# Direct USB4/Thunderbolt host-to-host networking between paired machines.
# Uses thunderbolt_net kernel module over USB4 cable for ~40 Gbps link.
# Assign static IPs on a /28 and trust the interface for unrestricted traffic.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Static IP map — each machine gets a unique address on the thunderbolt /28
  tbAddresses = {
    aspen1 = "10.10.10.1/28";
    aspen2 = "10.10.10.2/28";
    britton-desktop = "10.10.10.3/28";
  };

  hostname = config.networking.hostName;
  address = tbAddresses.${hostname} or null;
in
{
  config = lib.mkIf (address != null) {
    # Trust the thunderbolt bridge — no firewall filtering
    networking.firewall.trustedInterfaces = [ "br-tbt" ];

    # Static IP via networkd bridge setup. We bridge all thunderbolt-net interfaces
    # to support multi-port hub machines (aspen1) while remaining compatible with
    # single-port leaf nodes.
    systemd.network = {
      enable = true;
      netdevs."40-thunderbolt-bridge" = {
        netdevConfig = {
          Name = "br-tbt";
          Kind = "bridge";
        };
        bridgeConfig = {
          HelloTimeSec = 0;
          ForwardDelaySec = 0;
          STP = "no";
        };
      };
      networks."50-thunderbolt-members" = {
        matchConfig.Driver = "thunderbolt-net";
        networkConfig.Bridge = "br-tbt";
        linkConfig = {
          # Max frame size for throughput — thunderbolt_net supports 65536
          MTUBytes = "65520";
        };
      };
      networks."60-thunderbolt-bridge" = {
        matchConfig.Name = "br-tbt";
        address = [ address ];
        networkConfig = {
          DHCP = "no";
          LinkLocalAddressing = "no";
        };
        linkConfig = {
          MTUBytes = "65520";
        };
      };
    };

    # Bounce thunderbolt-net interfaces when the controller reports a hop
    # deactivation failure — the bridge port recovers on its own but the
    # thunderbolt_net driver's TX queue stays stuck until a link cycle.
    systemd.services.thunderbolt-net-recovery = {
      description = "Bounce thunderbolt-net interfaces after hop deactivation failure";
      after = [ "systemd-networkd.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 5;
      };
      path = [
        pkgs.iproute2
        pkgs.coreutils
        pkgs.systemd
      ];
      script = ''
        journalctl -k -f -o cat | while IFS= read -r line; do
          case "$line" in
            *"hop deactivation failed"*)
              echo "Thunderbolt hop failure detected, bouncing interfaces in 3s..."
              sleep 3
              for iface in /sys/class/net/thunderbolt*; do
                [ -e "$iface" ] || continue
                name=$(basename "$iface")
                ip link set "$name" down
                # Reset the fq qdisc — the driver's TX ring can wedge after a
                # hop failure, leaving packets stuck in the backlog forever.
                tc qdisc replace dev "$name" root fq
                sleep 2
                ip link set "$name" up
                echo "Bounced $name (qdisc reset)"
              done
              ;;
          esac
        done
      '';
    };

    # Prevent NetworkManager from touching the thunderbolt interface
    networking.networkmanager.unmanaged = [ "driver:thunderbolt-net" ];
  };
}
