# The NixOS tag and this host renderer share the policy and guard body.
fun onix =>
  let policy = import "../../inventory/tags/thunderbolt-link.json" in
  let guard_body = import "../../inventory/tags/thunderbolt-link-guard.sh" as 'Text in
  let quoted = fun value => "\"%{value}\"" in
  let words = fun values => values |> std.array.map quoted |> std.string.join " " in
  let nft_set = fun values => "{ %{std.string.join ", " values} }" in
  ({
    interface = {
      manifest = {
        name = "onix-core/thunderbolt-link",
        description = "Static USB4 bridge, configured-peer filter and link guard for OnixOS systemd hosts.",
        categories = ["network"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS machines use inventory/tags/thunderbolt-link.nix with the same policy and guard",
          }
        ],
      },
      packages = ["bash", "coreutils", "gnugrep", "iproute2", "iputils"],
      roles.host = {},
    },
    impl = fun args =>
      let p = args.package_paths in
      let address = std.record.get args.machine_name policy.tbAddresses in
      let peers = std.record.remove args.machine_name policy.tbAddresses in
      let peer_names = std.record.fields peers |> std.array.sort std.string.compare in
      let peer_addresses = peer_names |> std.array.map (fun name => std.record.get name peers) in
      let interfaces = [policy.bridgeName] @ policy.linkMembers in
      let interface_set = nft_set (std.array.map quoted interfaces) in
      let peer_set = nft_set peer_addresses in
      let guard_header = m%"
        #!%{p.bash}/bin/bash
        set -euo pipefail
        export PATH=%{p.coreutils}/bin:%{p.gnugrep}/bin:%{p.iproute2}/bin:%{p.iputils}/bin
        bridge=%{policy.bridgeName}
        address=%{address}/%{std.to_string policy.subnetPrefixLength}
        expected_mtu=%{std.to_string policy.linkMtuBytes}
        link_interfaces=( %{words interfaces} )
        link_members=( %{words policy.linkMembers} )
        peer_names=( %{words peer_names} )
        peer_addresses=( %{words peer_addresses} )
        ping_count=%{std.to_string policy.guardPeerPingCount}
        ping_timeout=%{std.to_string policy.guardPeerPingTimeoutSeconds}
        ping_attempts=%{std.to_string policy.guardPeerPingAttempts}
        ping_attempt_interval_seconds=%{std.to_string policy.guardPeerPingAttemptIntervalSeconds}
        settle_seconds=%{std.to_string policy.guardLinkSettleSeconds}
        repair_wait_attempts=%{std.to_string policy.guardRepairWaitAttempts}
        repair_wait_interval_seconds=%{std.to_string policy.guardRepairWaitIntervalSeconds}
        cooldown_seconds=%{std.to_string policy.guardRecoveryCooldownSeconds}
        state_dir=%{policy.guardStateDirectory}
        recovery_marker=%{policy.guardStateDirectory}/last-recovery
        exit_unhealthy=%{std.to_string policy.guardExitUnhealthy}
      "%
      in
      {
        output.host = {
          packages = [p.bash, p.coreutils, p.gnugrep, p.iproute2, p.iputils],
          kernel.modules = ["bridge", "thunderbolt-net"],
          wants."multi-user.target" = ["systemd-networkd.service"],
          network = {
            "%{policy.bridgeNetdev}.netdev" = m%"
              [NetDev]
              Kind=bridge
              Name=%{policy.bridgeName}
              [Bridge]
              HelloTimeSec=0
              ForwardDelaySec=0
              STP=no
            "%,
            "%{policy.memberNetwork}.network" = m%"
              [Match]
              Driver=%{policy.memberDriver}
              [Link]
              MTUBytes=%{std.to_string policy.linkMtuBytes}
              [Network]
              Bridge=%{policy.bridgeName}
            "%,
            "%{policy.bridgeNetwork}.network" = m%"
              [Match]
              Name=%{policy.bridgeName}
              [Link]
              MTUBytes=%{std.to_string policy.linkMtuBytes}
              [Network]
              Address=%{address}/%{std.to_string policy.subnetPrefixLength}
              DHCP=no
              LinkLocalAddressing=no
              IPv6AcceptRA=no
            "%,
          },
          files = {
            "thunderbolt-link/guard.sh" = { text = guard_header ++ "\n" ++ guard_body, mode = "0755" },
            "udev/rules.d/90-thunderbolt-link.rules".text = m%"
              ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="deactivated", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
              ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="activated", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
              ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="low bandwidth", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
              ACTION=="change", SUBSYSTEM=="thunderbolt", ENV{TUNNEL_EVENT}=="insufficient bandwidth", TAG+="systemd", ENV{SYSTEMD_WANTS}+="thunderbolt-link-guard.service"
            "%,
          },
          units = {
            "thunderbolt-link-guard.service" = {
              sections = {
                Unit = {
                  Description = "Verify and repair the USB4/Thunderbolt host-to-host link",
                  Wants = "systemd-networkd.service",
                  After = "systemd-networkd.service",
                  StartLimitIntervalSec = std.to_string policy.guardStartLimitIntervalSeconds,
                  StartLimitBurst = std.to_string policy.guardStartLimitBurst,
                },
                Service = { Type = "oneshot", ExecStart = "%{p.bash}/bin/bash /etc/thunderbolt-link/guard.sh" },
              },
            },
            "thunderbolt-link-guard.timer" = {
              sections = {
                Unit.Description = "Periodically verify the USB4/Thunderbolt host-to-host link",
                Timer = {
                  OnBootSec = "%{std.to_string policy.guardBootDelaySeconds}s",
                  OnUnitInactiveSec = "%{std.to_string policy.guardIntervalSeconds}s",
                  AccuracySec = "%{std.to_string policy.guardTimerAccuracySeconds}s",
                  Unit = "thunderbolt-link-guard.service",
                },
              },
              wanted_by = ["timers.target"],
            },
          },
          firewall = {
            enable = true,
            extra_input_rules = ["iifname %{interface_set} ip saddr %{peer_set} counter accept comment \"thunderbolt link: configured peers\""],
            extra_tables."inet %{policy.filterTableName}" = m%"
              chain input {
                type filter hook input priority %{std.to_string policy.filterPriority}; policy accept;
                iifname %{interface_set} ip saddr != %{peer_set} counter drop comment "thunderbolt link: only configured peers may send IPv4"
                iifname %{interface_set} meta nfproto ipv6 counter drop comment "thunderbolt link: IPv6 is not configured"
              }
              chain forward {
                type filter hook forward priority %{std.to_string policy.filterPriority}; policy accept;
                iifname %{interface_set} counter drop comment "thunderbolt link: never a transit network"
                oifname %{interface_set} counter drop comment "thunderbolt link: never a transit network"
              }
            "%,
          },
        },
      },
  }
  ) | onix.ServiceModule
