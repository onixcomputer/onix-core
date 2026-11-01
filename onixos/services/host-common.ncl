# Common settings of onix-core's NixOS machines (inventory/tags/nixos.nix,
# inventory/tags/common/*) for OnixOS systemd hosts, as a typed module.
#
# The groups other modules place users in exist here with NixOS's static ids
# (networkmanager 57, docker 131), and the login shells user accounts name are
# installed. The rest of the nixos tag follows NixOS's rendering of it:
# NetworkManager next to networkd, nsncd answering NSS lookups with the systemd
# and nss-mdns modules, Avahi, irqbalance, a tmpfs /tmp, the tag's sysctls,
# stop timeout, NTP servers and locale, and the nftables firewall. The tag's
# Nix pieces (nix-daemon settings, gcroot cleanup, nix-index) are not ported:
# OnixOS hosts run no Nix daemon.
fun onix =>
  let nm_units = [
    "NetworkManager.service",
    "NetworkManager-dispatcher.service",
    "NetworkManager-wait-online.service",
    "nm-priv-helper.service",
  ]
  in
  let locale_vars = ["LC_ADDRESS", "LC_IDENTIFICATION", "LC_MEASUREMENT", "LC_MONETARY", "LC_NAME", "LC_NUMERIC", "LC_PAPER", "LC_TELEPHONE", "LC_TIME"] in
  let host_impl = fun args =>
    let p = args.package_paths in
    let cfg = args.settings in
    let nss_path = "%{p.systemd}/lib:%{p."nss-mdns"}/lib" in
    {
      output.host = {
        groups = {
          networkmanager = { gid = 57 },
          docker = { gid = 131 },
          nscd = {},
          avahi = {},
        },
        users = {
          nscd = { group = "nscd", description = "nscd user" },
          avahi = { group = "avahi", description = "avahi-daemon privilege separation user" },
        },
        packages = [p.fish, p.avahi, p.networkmanager, p."kitty-terminfo", p."wezterm-terminfo"],
        environment = {
          LANG = cfg.locale,
          TERMINFO_DIRS = "/run/current-system/sw/share/terminfo",
        },
        units = {
          "nscd.service" = {
            sections = {
              Unit = {
                Description = "Name Service Cache Daemon (nsncd)",
                Before = "nss-lookup.target nss-user-lookup.target",
                Wants = "nss-lookup.target nss-user-lookup.target",
              },
              Service = {
                Environment = ["\"LD_LIBRARY_PATH=%{nss_path}\"", "NSNCD_HANDOFF_TIMEOUT=10"],
                ExecStart = "%{p.nsncd}/bin/nsncd",
                Type = "notify",
                User = "nscd",
                Group = "nscd",
                RuntimeDirectory = "nscd",
                PIDFile = "/run/nscd/nscd.pid",
                NoNewPrivileges = "true",
                PrivateTmp = "true",
                ProtectHome = "read-only",
                # nsncd writes its pid and cache outside /run; keep /usr, /boot and
                # /efi read-only but leave /var writable, its own directories owned.
                ProtectSystem = "full",
                StateDirectory = "nscd",
                CacheDirectory = "nscd",
                RemoveIPC = "true",
                Restart = "always",
                RestrictSUIDSGID = "true",
              },
            },
            wanted_by = ["multi-user.target"],
          },
          "avahi-daemon.socket" = {
            sections = {
              Unit = { Description = "Avahi mDNS/DNS-SD Stack Activation Socket", After = "systemd-tmpfiles-setup.service" },
              Socket.ListenStream = "/run/avahi-daemon/socket",
            },
            wanted_by = ["sockets.target"],
          },
          "avahi-daemon.service" = {
            sections = {
              Unit = {
                Description = "Avahi mDNS/DNS-SD Stack",
                Requires = "avahi-daemon.socket",
              },
              Service = {
                Environment = "\"LD_LIBRARY_PATH=%{nss_path}\"",
                BusName = "org.freedesktop.Avahi",
                CapabilityBoundingSet = ["CAP_SYS_CHROOT", "CAP_SETUID", "CAP_SETGID"],
                ConfigurationDirectory = "avahi/services",
                DevicePolicy = "closed",
                ExecStart = "%{p.avahi}/sbin/avahi-daemon -f /etc/avahi/avahi-daemon.conf",
                LockPersonality = "true",
                MemoryDenyWriteExecute = "true",
                NoNewPrivileges = "true",
                NotifyAccess = "main",
                PrivateDevices = "true",
                PrivateTmp = "true",
                PrivateUsers = "false",
                ProcSubset = "pid",
                ProtectClock = "true",
                ProtectControlGroups = "true",
                ProtectHome = "true",
                ProtectHostname = "true",
                ProtectKernelLogs = "true",
                ProtectKernelModules = "true",
                ProtectKernelTunables = "true",
                ProtectProc = "invisible",
                ProtectSystem = "strict",
                RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_NETLINK", "AF_UNIX"],
                RestrictNamespaces = "true",
                RestrictRealtime = "true",
                RestrictSUIDSGID = "true",
                SystemCallArchitectures = "native",
                SystemCallFilter = ["@system-service", "~@privileged", "@chown setgroups setresuid"],
                Type = "dbus",
                UMask = "0077",
              },
            },
            wanted_by = ["multi-user.target"],
          },
          "tmp.mount" = {
            sections = {
              Unit = {
                Description = "Temporary Directory /tmp",
                ConditionPathIsSymbolicLink = "!/tmp",
                DefaultDependencies = "no",
                Conflicts = "umount.target",
                Before = "local-fs.target umount.target",
                After = "swap.target",
              },
              Mount = {
                What = "tmpfs",
                Where = "/tmp",
                Type = "tmpfs",
                Options = "mode=1777,strictatime,rw,nosuid,nodev,size=50%,huge=never",
              },
            },
            wanted_by = ["local-fs.target"],
          },
        },
        package_units = [
          { package = p.networkmanager, dir = "etc/systemd/system", units = nm_units },
          { package = p.irqbalance, units = ["irqbalance.service"] },
        ],
        unit_aliases = {
          "dbus-org.freedesktop.NetworkManager.service" = "NetworkManager.service",
          "dbus-org.freedesktop.nm-dispatcher.service" = "NetworkManager-dispatcher.service",
        },
        dropins = {
          "NetworkManager.service"."onixos.conf" = m%"
            [Service]
            StateDirectory=NetworkManager
            StateDirectoryMode=755
          "%,
        },
        wants = {
          "multi-user.target" = ["NetworkManager.service", "NetworkManager-dispatcher.service", "irqbalance.service"],
        },
        dbus_packages = [p.avahi, p.networkmanager],
        # avahi daemonises into its runtime directory as the avahi user before it
        # drops privileges; the socket unit's directory is root-owned.
        tmpfiles = [
          "d /etc/NetworkManager/system-connections 0700 root root -",
          "d /var/lib/misc 0755 root root -",
          "d /run/avahi-daemon 0755 avahi avahi -",
        ],
        files = {
          "NetworkManager/NetworkManager.conf".text = m%"
            [connection]
            ethernet.cloned-mac-address=preserve
            wifi.cloned-mac-address=preserve

            [device]
            wifi.backend=wpa_supplicant
            wifi.scan-rand-mac-address=true

            [keyfile]
            path=/etc/NetworkManager/system-connections
            unmanaged-devices=%{std.string.join ";" cfg.networkmanager_unmanaged}

            [logging]
            audit=false
            level=WARN

            [main]
            dhcp=internal
            dns=systemd-resolved
            plugins=keyfile
            rc-manager=unmanaged
          "%,
          "avahi/avahi-daemon.conf".text = m%"
            [publish]
            disable-publishing=yes
            disable-user-service-publishing=yes
            publish-addresses=no
            publish-domain=no
            publish-hinfo=no
            publish-workstation=no

            [reflector]
            enable-reflector=no

            [server]
            allow-point-to-point=no
            browse-domains=
            domain-name=local
            host-name=%{args.machine_name}
            use-ipv4=yes
            use-ipv6=yes
          "%,
          "systemd/system.conf.d/host-common.conf".text = m%"
            [Manager]
            DefaultTimeoutStopSec=5s
          "%,
          "systemd/timesyncd.conf.d/host-common.conf".text = m%"
            [Time]
            NTP=%{std.string.join " " cfg.ntp_servers}
          "%,
          "locale.conf".text =
            (["LANG=%{cfg.locale}"] @ std.array.map (fun v => "%{v}=%{cfg.locale}") locale_vars |> std.string.join "\n") ++ "\n",
        },
        sysctl = {
          "net.core.default_qdisc" = "fq",
          "net.ipv4.tcp_congestion_control" = "bbr",
          "net.ipv4.tcp_fastopen" = "3",
          "fs.inotify.max_user_watches" = "1048576",
          "fs.inotify.max_user_instances" = "1024",
        },
        firewall = {
          enable = true,
          allowed_udp_ports = [5353],
        },
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/host-common",
        description = "The nixos tag of onix-core's machines (network, name service, mDNS, IRQ balancing, /tmp, sysctls, locale, firewall) for OnixOS systemd hosts.",
        categories = ["system"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts only; NixOS machines get these from inventory/tags/nixos.nix",
          },
        ],
      },
      packages = [
        "fish",
        "systemd",
        "nsncd",
        "nss-mdns=nssmdns",
        "avahi",
        "networkmanager",
        "irqbalance",
        "kitty-terminfo=kitty.terminfo",
        "wezterm-terminfo=wezterm.terminfo",
      ],
      roles.host = {
        networkmanager_unmanaged
          | doc "NetworkManager keyfile unmanaged-devices entries (e.g. driver:thunderbolt-net)."
          | Array String
          | default
          = [],
        ntp_servers | Array String | default = ["0.nixos.pool.ntp.org", "1.nixos.pool.ntp.org", "2.nixos.pool.ntp.org", "3.nixos.pool.ntp.org"],
        locale | String | default = "en_US.UTF-8",
      },
    },

    impl = host_impl,

    tests | not_exported =
      let pkgs = {
        fish = "fish-pkg",
        systemd = "systemd-pkg",
        nsncd = "nsncd-pkg",
        "nss-mdns" = "mdns-pkg",
        avahi = "avahi-pkg",
        networkmanager = "nm-pkg",
        irqbalance = "irq-pkg",
        "kitty-terminfo" = "kitty-ti",
        "wezterm-terminfo" = "wezterm-ti",
      }
      in
      let test_settings = { networkmanager_unmanaged = ["driver:thunderbolt-net", "interface-name:br-tbt"], ntp_servers = ["a", "b"], locale = "en_US.UTF-8" } in
      let out = (host_impl (onix.testing.mock_args { service = "host-common", role_name = 'host, settings = test_settings, packages = pkgs, machine_name = "aspen2" })).output.host in
      [
        out.groups.networkmanager.gid == 57,
        out.groups.docker.gid == 131,
        std.array.elem "fish-pkg" out.packages,
        # nsncd and Avahi load the systemd and nss-mdns NSS modules, as NixOS's units do.
        std.string.contains "LD_LIBRARY_PATH=systemd-pkg/lib:mdns-pkg/lib" (std.array.first out.units."nscd.service".sections.Service.Environment),
        std.string.contains "unmanaged-devices=driver:thunderbolt-net;interface-name:br-tbt" out.files."NetworkManager/NetworkManager.conf".text,
        std.string.contains "host-name=aspen2" out.files."avahi/avahi-daemon.conf".text,
        std.string.contains "NTP=a b" out.files."systemd/timesyncd.conf.d/host-common.conf".text,
        std.string.contains "LC_TIME=en_US.UTF-8" out.files."locale.conf".text,
        out.firewall.enable,
        std.array.elem 5353 out.firewall.allowed_udp_ports,
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
