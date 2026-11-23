# Direct USB4/Thunderbolt host-to-host networking between paired machines.
#
# The link trains at USB4 Gen 3x2 (two lanes, 20 Gb/s per lane in each
# direction) and the thunderbolt-net driver splits every packet into 4 KiB
# frames. Only two link properties can be tuned from the host side: the
# interface MTU and the health of the XDomain DMA path. Both are pinned here.
#
# The link is deliberately not a trusted network. Only the addresses in
# tbAddresses may reach local services, and nothing is forwarded between this
# link and any other interface.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  policy = builtins.fromJSON (builtins.readFile ./thunderbolt-link.json);
  # ---- link identity -------------------------------------------------------
  inherit (policy)
    bridgeName
    bridgeNetdev
    memberNetwork
    bridgeNetwork
    memberDriver
    ;

  # Bridge ports. A host with more than one USB4 controller can carry more than
  # one member, and a missing name is skipped everywhere it is used.
  inherit (policy) linkMembers;

  # Everything that may carry link traffic. Packets that the bridge delivers to
  # the local host still arrive with the bridge as their input interface, but a
  # member that fell out of the bridge must not become a way past the filter.
  linkInterfaces = [ bridgeName ] ++ linkMembers;

  # ---- link parameters -----------------------------------------------------
  # thunderbolt0 reports maxmtu 65522 and the bridge header costs two bytes, so
  # 65520 is the largest usable MTU. The driver splits every packet into 4 KiB
  # frames, therefore the MTU is what removes per-packet overhead.
  inherit (policy) linkMtuBytes subnetPrefixLength;

  # ---- link filter ---------------------------------------------------------
  # Runs before the NixOS firewall input hook (priority filter is 0) so that the
  # peer allow-list cannot be widened by a port opened for another interface,
  # and so that a device that is not a configured peer cannot reach any local
  # service.
  inherit (policy) filterPriority filterTableName;

  # ---- guard ---------------------------------------------------------------
  inherit (policy)
    guardPeerPingCount
    guardPeerPingTimeoutSeconds
    guardPeerPingAttempts
    guardPeerPingAttemptIntervalSeconds
    guardLinkSettleSeconds
    guardRepairWaitAttempts
    guardRepairWaitIntervalSeconds
    guardRecoveryCooldownSeconds
    guardStateDirectory
    guardExitUnhealthy
    ;
  guardRecoveryMarker = "${guardStateDirectory}/last-recovery";
  # Every link flap raises two TUNNEL_EVENTs and the guard is cheap and
  # serialized by systemd, so this limit only has to stop an unbounded storm.
  # A tight limit would strand the guard in start-limit-hit while the link is
  # still broken.
  inherit (policy)
    guardStartLimitIntervalSeconds
    guardStartLimitBurst
    guardBootDelaySeconds
    guardIntervalSeconds
    guardTimerAccuracySeconds
    ;

  # ---- address map ---------------------------------------------------------
  # Every host that may speak on the link. The map is the single source of truth
  # for the static addresses, the input allow-list, and the peer health checks.
  inherit (policy) tbAddresses;

  hostname = config.networking.hostName;
  address = tbAddresses.${hostname} or null;
  peerHosts = lib.removeAttrs tbAddresses [ hostname ];
  peerNames = lib.attrNames peerHosts;
  peerAddresses = lib.attrValues peerHosts;

  nftInterfaceSet = "{ ${lib.concatMapStringsSep ", " (iface: ''"${iface}"'') linkInterfaces} }";
  nftPeerSet = "{ ${lib.concatStringsSep ", " peerAddresses} }";
  shellWordList = names: lib.concatStringsSep " " (map (name: ''"${name}"'') names);

  guard = pkgs.writeShellApplication {
    name = "thunderbolt-link-guard";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      iproute2
      iputils
    ];
    text = ''
      bridge=${bridgeName}
      address=${address}/${toString subnetPrefixLength}
      expected_mtu=${toString linkMtuBytes}
      link_interfaces=( ${shellWordList linkInterfaces} )
      link_members=( ${shellWordList linkMembers} )
      peer_names=( ${shellWordList peerNames} )
      peer_addresses=( ${shellWordList peerAddresses} )
      ping_count=${toString guardPeerPingCount}
      ping_timeout=${toString guardPeerPingTimeoutSeconds}
      ping_attempts=${toString guardPeerPingAttempts}
      ping_attempt_interval_seconds=${toString guardPeerPingAttemptIntervalSeconds}
      settle_seconds=${toString guardLinkSettleSeconds}
      repair_wait_attempts=${toString guardRepairWaitAttempts}
      repair_wait_interval_seconds=${toString guardRepairWaitIntervalSeconds}
      cooldown_seconds=${toString guardRecoveryCooldownSeconds}
      state_dir=${guardStateDirectory}
      recovery_marker=${guardRecoveryMarker}
      exit_unhealthy=${toString guardExitUnhealthy}
    ''
    + builtins.readFile ./thunderbolt-link-guard.sh;
  };
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = address != null;
          message = ''
            The thunderbolt-link tag requires a static USB4 address for ${hostname}.
            Add ${hostname} to tbAddresses in inventory/tags/thunderbolt-link.json
            before assigning the tag.
          '';
        }
      ];
    }

    (lib.mkIf (address != null) {
      networking = {
        # Deny every packet that is not from a configured peer before any port
        # rule can see it. Grants stay in the NixOS firewall below: a base chain
        # that runs first is a reliable place to deny, but the port-level grants
        # belong with the rest of the host policy where they are reviewable.
        nftables.tables.${filterTableName} = {
          family = "inet";
          content = ''
            chain input {
              type filter hook input priority ${toString filterPriority}; policy accept;

              iifname ${nftInterfaceSet} ip saddr != ${nftPeerSet} counter drop comment "thunderbolt link: only configured peers may send IPv4"
              iifname ${nftInterfaceSet} meta nfproto ipv6 counter drop comment "thunderbolt link: IPv6 is not configured"
            }

            chain forward {
              type filter hook forward priority ${toString filterPriority}; policy accept;

              iifname ${nftInterfaceSet} counter drop comment "thunderbolt link: never a transit network"
              oifname ${nftInterfaceSet} counter drop comment "thunderbolt link: never a transit network"
            }
          '';
        };

        # Configured peers may reach any local service over the link. Ray and
        # NCCL open ephemeral ports, so a port list cannot express this policy.
        firewall.extraInputRules = ''
          iifname ${nftInterfaceSet} ip saddr ${nftPeerSet} counter accept comment "thunderbolt link: configured peers"
        '';

        # NetworkManager must not own the raw USB4 interface nor the bridge.
        networkmanager.unmanaged = [
          "driver:${memberDriver}"
          "interface-name:${bridgeName}"
        ];
      };

      # Static address on the bridge. Members match by driver, so a machine with
      # several USB4 ports (aspen1) and a machine with one port (aspen2) both end
      # up on the same bridge.
      systemd = {
        network = {
          enable = true;
          netdevs.${bridgeNetdev} = {
            netdevConfig = {
              Name = bridgeName;
              Kind = "bridge";
            };
            bridgeConfig = {
              HelloTimeSec = 0;
              ForwardDelaySec = 0;
              STP = "no";
            };
          };
          networks.${memberNetwork} = {
            matchConfig.Driver = memberDriver;
            networkConfig.Bridge = bridgeName;
            linkConfig = {
              # Max frame size for throughput; the driver caps it at 65522.
              MTUBytes = toString linkMtuBytes;
            };
          };
          networks.${bridgeNetwork} = {
            matchConfig.Name = bridgeName;
            address = [ "${address}/${toString subnetPrefixLength}" ];
            networkConfig = {
              DHCP = "no";
              LinkLocalAddressing = "no";
              IPv6AcceptRA = "no";
            };
            linkConfig = {
              MTUBytes = toString linkMtuBytes;
            };
          };
        };

        # The guard verifies the link, repairs a wedged DMA path, and re-applies
        # the MTU and the per-interface sysctls when they drift.
        services.thunderbolt-link-guard = {
          description = "Verify and repair the USB4/Thunderbolt host-to-host link";
          wants = [ "systemd-networkd.service" ];
          after = [ "systemd-networkd.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${guard}/bin/thunderbolt-link-guard";
          };
          unitConfig = {
            # The guard has its own cooldown; this limit only stops a udev storm
            # from restarting the unit without bound.
            StartLimitIntervalSec = guardStartLimitIntervalSeconds;
            StartLimitBurst = guardStartLimitBurst;
          };
        };

        timers.thunderbolt-link-guard = {
          description = "Periodically verify the USB4/Thunderbolt host-to-host link";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = guardBootDelaySeconds;
            OnUnitInactiveSec = guardIntervalSeconds;
            AccuracySec = guardTimerAccuracySeconds;
            Unit = "thunderbolt-link-guard.service";
          };
        };
      };

      # The kernel reports XDomain tunnel state changes on the USB4 domain
      # device as TUNNEL_EVENT. Ask the guard to re-verify after any tunnel is
      # torn down, brought up, or reported as bandwidth limited.
      services.udev.extraRules = ''
        ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="deactivated", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
        ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="activated", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
        ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="low bandwidth", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
        ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="insufficient bandwidth", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
      '';
    })
  ];
}
