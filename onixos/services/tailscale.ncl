# Tailscale mesh VPN peer.
#
# Port of onix-core's Clan tailscale service (modules/tailscale, role peer):
# same settings, defaults and NixOS output. The auth key is the shared
# artifact tailscale-<instance>, named like the Clan generator. With
# services.tailscale.authKeyFile set, nixpkgs' tailscaled-autoconnect unit
# runs `tailscale up --auth-key ... <extraUpFlags>` until the node is up.
# tailscale-host-sync (modules/tailscale/host-sync.nix) writes Tailscale
# device names into /etc/hosts every minute; its script runs as a strict
# unit script (same bash options and shellcheck as Clan's
# writeShellApplication) with the runtime inputs on the unit PATH.
# mk-nixos-config.nix's tailscaled-autoconnect override is not ported: it
# needs services.tailscale.autoconnect, which this nixpkgs does not have.
# NixOS also installs the package's tailscale-online.target and
# tailscale-wait-online.service as linkable units, without enabling the target.
fun onix =>
  let nixos_lib = import "../lib/nixos.ncl" in
  let tailscale_udp_port = 41641 in
  # services.tailscale options this module sets itself; Clan's freeform peer
  # settings could not change them either.
  let owned_options = ["enable", "authKeyFile", "extraUpFlags", "useRoutingFeatures"] in
  let valid_extra_options = fun value =>
    std.is_record value
    && (std.record.fields value |> std.array.all (fun option => !(std.array.elem option owned_options)))
  in
  let ExtraOptions = std.contract.from_predicate valid_extra_options in
  let host_sync_script =
    m%"
      # Exit if tailscale isn't ready
      tailscale status --json &>/dev/null || exit 0

      # Get current peers
      TEMP=$(mktemp)
      trap 'rm -f "$TEMP"' EXIT

      tailscale status --json | \
        jq -r '.Peer[] | select(.DNSName and .DNSName != "") | .DNSName as $dns | select($dns | split(".")[0] != "" and ($dns | split(".")[0] != null)) | "\(.TailscaleIPs[0]) \($dns | split(".")[0])"' | \
        grep -v " null$" | \
        sort > "$TEMP"

      # Get existing tailscale entries from /etc/hosts
      OLD_CONTENT=$(sed -n '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/p' /etc/hosts 2>/dev/null | \
        sed '1d;$d' | sort)
      NEW_CONTENT=$(cat "$TEMP")

      # Only update if content changed
      if [ "$OLD_CONTENT" != "$NEW_CONTENT" ]; then
        sed '/# TAILSCALE-ALIASES-START/,/# TAILSCALE-ALIASES-END/d' /etc/hosts > /etc/hosts.new

        if [ -s "$TEMP" ]; then
          {
            echo "# TAILSCALE-ALIASES-START"
            cat "$TEMP"
            echo "# TAILSCALE-ALIASES-END"
          } >> /etc/hosts.new
        fi

        mv -f /etc/hosts.new /etc/hosts
      fi
    "%
    ++ "\n"
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/tailscale",
        description = "Tailscale mesh VPN peer with Tailscale device names in /etc/hosts.",
        categories = ["networking", "vpn"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "configures the NixOS Tailscale service, firewall and the host-sync unit",
          },
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "tailscaled, its autoconnect and the host sync on an OnixOS systemd host; exit nodes and freeform options are NixOS-only",
          },
        ],
      },
      packages = ["tailscale", "jq", "gnused", "coreutils", "gnugrep"],
      roles.peer = {
        enable_ssh
          | doc "Enable Tailscale SSH (tailscale up --ssh)."
          | Bool
          | priority -5
          = false,
        exit_node
          | doc "Advertise as exit node (tailscale up --advertise-exit-node) and NAT tailscale0 out of exit_node_external_interface."
          | Bool
          | priority -5
          = false,
        enable_host_aliases
          | doc "Sync Tailscale device names to /etc/hosts every minute."
          | Bool
          | priority -5
          = true,
        extra_up_flags
          | doc "Extra flags passed to tailscale up."
          | Array String
          | priority -5
          = [],
        exit_node_external_interface
          | doc "networking.nat.externalInterface (mkDefault) on exit nodes. Clan used \"eth0\" when networking.interfaces.eth0 was declared, else \"\"."
          | String
          | priority -5
          = "",
        extra_options
          | doc "Further services.tailscale options, passed through like Clan's freeform peer settings (e.g. { port = 41642 }). enable, authKeyFile, extraUpFlags and useRoutingFeatures belong to this module."
          | { _ : Dyn }
          | ExtraOptions
          | priority -5
          = {},
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let artifact_name = "tailscale-%{args.instance_name}" in
      let up_flags =
        (if cfg.enable_ssh then ["--ssh"] else [])
        @ (if cfg.exit_node then ["--advertise-exit-node"] else [])
        @ cfg.extra_up_flags
      in
      let host_sync = {
        systemd.services.tailscale-host-sync = {
          description = "Sync Tailscale hostnames to /etc/hosts",
          after = ["tailscaled.service"],
          path = [
            args.package_paths.tailscale,
            args.package_paths.jq,
            args.package_paths.gnused,
            args.package_paths.coreutils,
            args.package_paths.gnugrep,
          ],
          enableStrictShellChecks = true,
          script = host_sync_script,
          serviceConfig.Type = "oneshot",
        },
        systemd.timers.tailscale-host-sync = {
          wantedBy = ["timers.target"],
          timerConfig = {
            OnBootSec = "1min",
            OnUnitActiveSec = "1min",
          },
        },
      }
      in
      let exit_node_nat = {
        networking.nat = {
          enable = true,
          externalInterface = nixos_lib.mk_default cfg.exit_node_external_interface,
          internalInterfaces = ["tailscale0"],
        },
      }
      in
      # OnixOS systemd host: the package's tailscaled and online units with NixOS's
      # drop-in, its autoconnect script (auth key from the placed artifact) and host sync.
      let auth_key = "/run/artifacts/%{artifact_name}/auth_key" in
      let autoconnect_script =
        m%"
          set -o errexit
          set -o nounset
          set -o pipefail
          getState() {
            tailscale status --json --peers=false | jq -r '.BackendState'
          }
          lastState=""
          while state="$(getState)"; do
            if [[ "$state" != "$lastState" ]]; then
              case "$state" in
                NeedsLogin|NeedsMachineAuth|Stopped)
                  echo "Server needs authentication, sending auth key"
                  tailscale up --auth-key "$(cat %{auth_key})" %{std.string.join " " up_flags}
                  ;;
                Running)
                  echo "Tailscale is running"
                  systemd-notify --ready
                  exit 0
                  ;;
                *)
                  echo "Waiting for Tailscale State = Running or systemd timeout"
                  ;;
              esac
              echo "State = $state"
            fi
            lastState="$state"
            sleep .5
          done
        "%
        ++ "\n"
      in
      let tool_path = std.string.join ":" (std.array.map (fun p => "%{p}/bin") [args.package_paths.tailscale, args.package_paths.jq, args.package_paths.gnused, args.package_paths.coreutils, args.package_paths.gnugrep]) in
      let host_sync_host = {
        units."tailscale-host-sync.service" = {
          sections = {
            Unit = { Description = "Sync Tailscale hostnames to /etc/hosts", After = "tailscaled.service" },
            Service = {
              Type = "oneshot",
              Environment = "PATH=%{tool_path}",
              # NixOS runs this script without errexit: it exits 0 itself when the
              # node has no peers yet, which errexit would turn into a failure.
              ExecStart = "/run/current-system/sw/bin/bash /etc/tailscale/host-sync.sh",
            },
          },
        },
        units."tailscale-host-sync.timer" = {
          sections.Timer = { OnBootSec = "1min", OnUnitActiveSec = "1min" },
          wanted_by = ["timers.target"],
        },
        files."tailscale/host-sync.sh".text = host_sync_script,
      }
      in
      # Exit-node NAT and the freeform NixOS options have no host form yet: without a host
      # leaf a systemd-host build refuses the unit instead of dropping them.
      let host_leaf =
        if cfg.exit_node || cfg.extra_options != {} then
          {}
        else
          {
            package_units = [{ package = args.package_paths.tailscale, units = ["tailscaled.service", "tailscale-online.target", "tailscale-wait-online.service"] }],
            wants."multi-user.target" = ["tailscaled.service"],
            dropins."tailscaled.service"."onixos.conf" =
              m%"
              [Unit]
              After=NetworkManager-wait-online.service

              [Service]
              X-StopIfChanged=false
              Environment="PATH=/run/wrappers/bin:%{tool_path}:/run/current-system/sw/bin"
              Environment=PORT=%{std.to_string tailscale_udp_port}
              Environment="FLAGS=--tun tailscale0"
            "%
              ++ "\n",
            units."tailscaled-autoconnect.service" = {
              sections = {
                Unit = {
                  After = "tailscaled.service",
                  Wants = "tailscaled.service",
                  # The NixOS unit's ExecStart is a generated script path, so a
                  # script change changes this trigger and restarts autoconnect.
                  X-Restart-Triggers = std.hash 'Sha256 autoconnect_script,
                },
                Service = {
                  Type = "notify",
                  Environment = "PATH=%{tool_path}:/run/current-system/sw/bin",
                  ExecStart = "/run/current-system/sw/bin/bash /etc/tailscale/autoconnect.sh",
                },
              },
              wanted_by = ["tailscaled.service"],
            },
            files."tailscale/autoconnect.sh".text = autoconnect_script,
            # NixOS denies Tailscale's interface to dhcpcd. This host does not
            # run dhcpcd at all: NetworkManager owns ordinary links, while the
            # dedicated networkd config only owns the Thunderbolt bridge.
            # useRoutingFeatures = both.
            # services.tailscale creates this group: tailscalesd reads the socket
            # through it, as NixOS's tailscale module arranges.
            groups.tailscale = {},
            sysctl = { "net.ipv4.conf.all.forwarding" = "1", "net.ipv6.conf.all.forwarding" = "1" },
            firewall = { trusted_interfaces = ["tailscale0"], allowed_udp_ports = [tailscale_udp_port], reverse_path = "loose" },
            packages = [args.package_paths.tailscale],
          }
          & (if cfg.enable_host_aliases then host_sync_host else {})
      in
      {
        output =
          {
            host = host_leaf,
            nixos =
              {
                services.tailscale =
                  cfg.extra_options
                  & {
                    enable = true,
                    extraUpFlags = up_flags,
                    useRoutingFeatures = nixos_lib.mk_default "both",
                  },
                networking.firewall = {
                  checkReversePath = "loose",
                  trustedInterfaces = ["tailscale0"],
                  allowedUDPPorts = [tailscale_udp_port],
                },
                environment.systemPackages = [args.packages.tailscale],
              }
              & (if cfg.enable_host_aliases then host_sync else {})
              & (if cfg.exit_node then exit_node_nat else {}),
            artifact_wiring = [
              onix.artifact_wiring {
                artifact = artifact_name,
                file = "auth_key",
                nixos_option = "services.tailscale.authKeyFile",
              },
            ],
          }
          & onix.artifact_declaration {
            name = artifact_name,
            shared = true,
            files.auth_key = onix.artifact_file {},
            prompts.auth_key.description = "Tailscale auth key for instance '%{args.instance_name}'",
            generator_script = m%"
              cat "$prompts"/auth_key > "$out"/auth_key
            "%,
            description = "Tailscale auth key for %{args.instance_name}",
          },
      },

    tests | not_exported =
      let peer = interface.roles.peer in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "tailscale",
              role_name = 'peer,
              instance_name = "br-tailnet",
              settings = peer & overrides,
              packages = {
                tailscale = "tailscale-pkg",
                jq = "jq-pkg",
                gnused = "gnused-pkg",
                coreutils = "coreutils-pkg",
                gnugrep = "gnugrep-pkg",
              },
            }
          )
        ).output
      in
      let defaults = run {} in
      let aspen2 = run { enable_ssh = true, exit_node = false, enable_host_aliases = true } in
      let exit_out = run { exit_node = true, exit_node_external_interface = "eth0" } in
      let no_aliases = run { enable_host_aliases = false } in
      let host_leaf = aspen2.host in
      let host_sync = aspen2.nixos.systemd.services.tailscale-host-sync in
      let artifact = aspen2.artifacts."tailscale-br-tailnet" in
      let wiring = std.array.first aspen2.artifact_wiring in
      [
        # OnixOS systemd host: tailscaled from the package with NixOS's drop-in, autoconnect
        # reading the placed auth key, host sync every minute; exit nodes stay NixOS-only.
        std.string.contains "FLAGS=--tun tailscale0" host_leaf.dropins."tailscaled.service"."onixos.conf",
        std.string.contains "cat /run/artifacts/tailscale-br-tailnet/auth_key)\" --ssh" host_leaf.files."tailscale/autoconnect.sh".text,
        host_leaf.units."tailscale-host-sync.timer".sections.Timer == { OnBootSec = "1min", OnUnitActiveSec = "1min" },
        !(std.record.has_field "units" no_aliases.host && std.record.has_field "tailscale-host-sync.service" no_aliases.host.units),
        exit_out.host == {},
        # Clan defaults: no SSH, no exit node, host aliases on.
        defaults.nixos.services.tailscale.enable,
        defaults.nixos.services.tailscale.extraUpFlags == [],
        std.record.has_field "tailscale-host-sync" defaults.nixos.systemd.services,
        # Flags reach `tailscale up` in Clan's order.
        aspen2.nixos.services.tailscale.extraUpFlags == ["--ssh"],
        (run { enable_ssh = true, exit_node = true, extra_up_flags = ["--accept-dns=false"] }).nixos.services.tailscale.extraUpFlags == ["--ssh", "--advertise-exit-node", "--accept-dns=false"],
        # Routing features default to both but a machine can still override them.
        aspen2.nixos.services.tailscale.useRoutingFeatures.content == "both",
        aspen2.nixos.services.tailscale.useRoutingFeatures.priority == 1000,
        aspen2.nixos.networking.firewall.checkReversePath == "loose",
        aspen2.nixos.networking.firewall.trustedInterfaces == ["tailscale0"],
        aspen2.nixos.networking.firewall.allowedUDPPorts == [41641],
        aspen2.nixos.environment.systemPackages == ["tailscale-pkg"],
        # Exit nodes NAT tailscale0 out of the configured interface.
        !(std.record.has_field "nat" aspen2.nixos.networking),
        exit_out.nixos.networking.nat.enable,
        exit_out.nixos.networking.nat.internalInterfaces == ["tailscale0"],
        exit_out.nixos.networking.nat.externalInterface.content == "eth0",
        exit_out.nixos.networking.nat.externalInterface.priority == 1000,
        # Host sync: Clan's runtime inputs on the unit PATH, strict shell, 1-minute timer.
        host_sync.path == ["tailscale-pkg", "jq-pkg", "gnused-pkg", "coreutils-pkg", "gnugrep-pkg"],
        host_sync.enableStrictShellChecks,
        host_sync.after == ["tailscaled.service"],
        host_sync.serviceConfig.Type == "oneshot",
        std.string.contains "# TAILSCALE-ALIASES-START" host_sync.script,
        aspen2.nixos.systemd.timers.tailscale-host-sync.timerConfig == { OnBootSec = "1min", OnUnitActiveSec = "1min" },
        !(std.record.has_field "systemd" no_aliases.nixos),
        # Freeform services.tailscale options pass through; owned ones are rejected.
        (run { extra_options = { port = 41642 } }).nixos.services.tailscale.port == 41642,
        valid_extra_options { port = 41642, extraSetFlags = ["--accept-routes"] },
        !(valid_extra_options { authKeyFile = "/tmp/key" }),
        # Auth key: shared artifact named like the Clan generator, wired to authKeyFile.
        artifact.shared,
        artifact.files.auth_key.secret,
        artifact.files.auth_key.mode == "0400",
        artifact.prompts.auth_key.description == "Tailscale auth key for instance 'br-tailnet'",
        std.string.contains "cat \"$prompts\"/auth_key > \"$out\"/auth_key" artifact.generator_script,
        wiring.artifact == "tailscale-br-tailnet",
        wiring.file == "auth_key",
        wiring.nixos_option == "services.tailscale.authKeyFile",
        !(std.record.has_field "value" wiring),
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
