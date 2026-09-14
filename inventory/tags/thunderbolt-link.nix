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
  # ---- link identity -------------------------------------------------------
  bridgeName = "br-tbt";
  bridgeNetdev = "40-thunderbolt-bridge";
  memberNetwork = "50-thunderbolt-members";
  bridgeNetwork = "60-thunderbolt-bridge";
  memberDriver = "thunderbolt-net";

  # Bridge ports. A host with more than one USB4 controller can carry more than
  # one member, and a missing name is skipped everywhere it is used.
  linkMembers = [
    "thunderbolt0"
    "thunderbolt1"
  ];

  # Everything that may carry link traffic. Packets that the bridge delivers to
  # the local host still arrive with the bridge as their input interface, but a
  # member that fell out of the bridge must not become a way past the filter.
  linkInterfaces = [ bridgeName ] ++ linkMembers;

  # ---- link parameters -----------------------------------------------------
  # thunderbolt0 reports maxmtu 65522 and the bridge header costs two bytes, so
  # 65520 is the largest usable MTU. The driver splits every packet into 4 KiB
  # frames, therefore the MTU is what removes per-packet overhead.
  linkMtuBytes = 65520;
  subnetPrefixLength = 28;

  # ---- link filter ---------------------------------------------------------
  # Runs before the NixOS firewall input hook (priority filter is 0) so that the
  # peer allow-list cannot be widened by a port opened for another interface,
  # and so that a device that is not a configured peer cannot reach any local
  # service.
  filterPriority = -180;
  filterTableName = "thunderbolt-link";

  # ---- guard ---------------------------------------------------------------
  guardPeerPingCount = 1;
  guardPeerPingTimeoutSeconds = 5;
  guardPeerPingAttempts = 3;
  guardPeerPingAttemptIntervalSeconds = 2;
  guardLinkSettleSeconds = 3;
  guardRepairWaitAttempts = 10;
  guardRepairWaitIntervalSeconds = 2;
  guardRecoveryCooldownSeconds = 300;
  guardStateDirectory = "/run/thunderbolt-link";
  guardRecoveryMarker = "${guardStateDirectory}/last-recovery";
  guardExitUnhealthy = 1;
  # Every link flap raises two TUNNEL_EVENTs and the guard is cheap and
  # serialized by systemd, so this limit only has to stop an unbounded storm.
  # A tight limit would strand the guard in start-limit-hit while the link is
  # still broken.
  guardStartLimitIntervalSeconds = 60;
  guardStartLimitBurst = 30;
  guardBootDelaySeconds = 300;
  guardIntervalSeconds = 900;
  guardTimerAccuracySeconds = 60;

  # ---- address map ---------------------------------------------------------
  # Every host that may speak on the link. The map is the single source of truth
  # for the static addresses, the input allow-list, and the peer health checks.
  tbAddresses = {
    aspen1 = "10.10.10.1";
    aspen2 = "10.10.10.2";
    britton-desktop = "10.10.10.3";
  };

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

      log() {
        printf 'thunderbolt-link guard: %s\n' "$*"
      }

      set_sysctl() {
        local key="$1"
        local value="$2"
        local path="/proc/sys/$key"
        local current

        if [ ! -e "$path" ]; then
          return 0
        fi

        current="$(cat "$path")"
        if [ "$current" != "$value" ]; then
          printf '%s' "$value" > "$path"
          log "set $key=$value (was $current)"
        fi
      }

      # Keep the link from accepting redirects or source-routed packets from
      # whatever is plugged into the USB4 port.
      apply_sysctls() {
        local iface

        for iface in "''${link_interfaces[@]}"; do
          if [ ! -e "/sys/class/net/$iface" ]; then
            continue
          fi
          set_sysctl "net.ipv4.conf.$iface.accept_redirects" 0
          set_sysctl "net.ipv4.conf.$iface.send_redirects" 0
          set_sysctl "net.ipv4.conf.$iface.accept_source_route" 0
        done
      }

      carrier_up() {
        [ "$(cat "/sys/class/net/$bridge/carrier" 2>/dev/null || echo 0)" = 1 ]
      }

      address_present() {
        ip -o -4 addr show dev "$bridge" | grep -qF -- "$address"
      }

      mtu_matches() {
        [ "$(cat "/sys/class/net/$bridge/mtu" 2>/dev/null || echo 0)" = "$expected_mtu" ]
      }

      peer_reachable() {
        local attached=()
        local path
        local name
        local index
        local address
        local attempt

        # Only peers that the kernel reports as attached hosts can be verified.
        # A configured peer that is not plugged in is not a link failure.
        for path in /sys/bus/thunderbolt/devices/*/device_name; do
          if [ ! -e "$path" ]; then
            continue
          fi
          name="$(cat "$path")"
          for index in "''${!peer_names[@]}"; do
            if [ "''${peer_names[$index]}" = "$name" ]; then
              attached+=("''${peer_addresses[$index]}")
              break
            fi
          done
        done

        if [ "''${#attached[@]}" -eq 0 ]; then
          log "no configured peer is attached to the USB4 link; nothing to verify"
          return 0
        fi

        for address in "''${attached[@]}"; do
          for attempt in $(seq 1 "$ping_attempts"); do
            if ping -n -q -c "$ping_count" -W "$ping_timeout" "$address" >/dev/null 2>&1; then
              break
            fi
            if [ "$attempt" = "$ping_attempts" ]; then
              log "attached peer $address did not answer after $ping_attempts attempts"
              return 1
            fi
            sleep "$ping_attempt_interval_seconds"
          done
        done
      }

      healthy() {
        carrier_up && address_present && mtu_matches && peer_reachable
      }

      apply_link_params() {
        local member

        # Raise the members first: the bridge MTU is capped by its members.
        for member in "''${link_members[@]}"; do
          if [ ! -e "/sys/class/net/$member" ]; then
            continue
          fi
          if [ "$(cat "/sys/class/net/$member/mtu")" != "$expected_mtu" ]; then
            ip link set dev "$member" mtu "$expected_mtu"
            log "set $member mtu=$expected_mtu"
          fi
        done

        if ! mtu_matches; then
          ip link set dev "$bridge" mtu "$expected_mtu"
          log "set $bridge mtu=$expected_mtu"
        fi
      }

      # A wedged XDomain DMA path leaves the interface up while no frame reaches
      # the peer. A link cycle rebuilds the ring, the DMA path, and the qdisc,
      # which is the only host-side repair the driver offers.
      repair() {
        local member
        local attempt

        for member in "''${link_members[@]}"; do
          if [ ! -e "/sys/class/net/$member" ]; then
            continue
          fi
          log "bouncing $member"
          ip link set dev "$member" down
          tc qdisc replace dev "$member" root fq
          sleep "$settle_seconds"
          ip link set dev "$member" up
        done

        for attempt in $(seq 1 "$repair_wait_attempts"); do
          if ! address_present; then
            ip addr replace "$address" dev "$bridge"
          fi
          if carrier_up && address_present; then
            log "link members came back on attempt $attempt"
            break
          fi
          sleep "$repair_wait_interval_seconds"
        done

        apply_link_params
        apply_sysctls
      }

      main() {
        mkdir -p "$state_dir"
        apply_sysctls

        if [ ! -e "/sys/class/net/$bridge" ]; then
          log "$bridge does not exist on this host; nothing to verify"
          exit 0
        fi

        # No carrier means the cable or the far end is gone. No host-side action
        # can repair that, and the carrier state alerts on its own.
        if ! carrier_up; then
          log "$bridge has no carrier; the USB4 link is down and no host-side repair is possible"
          exit 0
        fi

        if healthy; then
          log "link healthy: $address, mtu $expected_mtu"
          exit 0
        fi

        local now last_repair=0
        now="$(date +%s)"
        if [ -r "$recovery_marker" ]; then
          last_repair="$(cat "$recovery_marker" 2>/dev/null || echo 0)"
        fi

        if [ "$last_repair" -ne 0 ] && [ $((now - last_repair)) -lt "$cooldown_seconds" ]; then
          log "link unhealthy and the last repair is inside the ''${cooldown_seconds}s cooldown; not bouncing again"
          exit "$exit_unhealthy"
        fi

        printf '%s' "$now" > "$recovery_marker"
        log "link unhealthy (address, mtu, or peer reachability); repairing"
        repair

        if healthy; then
          log "link healthy again after repair"
          exit 0
        fi

        log "link still unhealthy after repair"
        exit "$exit_unhealthy"
      }

      main "$@"
    '';
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
            Add ${hostname} to tbAddresses in inventory/tags/thunderbolt-link.nix
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
