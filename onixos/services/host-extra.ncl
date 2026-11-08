# Machine-level pieces of onix-core's NixOS tags that are not a service of their
# own, for OnixOS systemd hosts: weekly fstrim (nixos-hardware's common/pc/ssd),
# hourly logrotate, the scx scheduler (perf-tuning), polkit and ModemManager
# (NetworkManager's mobile-broadband helper), and the static LAN address that
# NixOS renders as network-addresses-<interface>.service.
fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    let cfg = args.settings in
    let address_unit = fun entry =>
      let name = "network-addresses-%{entry.interface}.service" in
      {
        "%{name}" = {
          sections = {
            Unit = {
              Description = "Address configuration of %{entry.interface}",
              After = "network-pre.target sys-subsystem-net-devices-%{entry.interface}.device",
              BindsTo = "sys-subsystem-net-devices-%{entry.interface}.device",
              PartOf = "networking-scripted.target",
            },
            Service = {
              Type = "oneshot",
              RemainAfterExit = "true",
              # Type=oneshot runs one ExecStart per element, in order.
              ExecStart =
                ["%{p.iproute2}/bin/ip address add %{std.string.join " " entry.addresses} dev %{entry.interface}"]
                @ (
                  if std.record.has_field "gateway" entry then
                    ["%{p.iproute2}/bin/ip route add default via %{entry.gateway} dev %{entry.interface}"]
                  else
                    []
                ),
              ExecStop = "%{p.iproute2}/bin/ip address flush dev %{entry.interface}",
              X-StopIfChanged = "false",
            },
          },
          wanted_by = ["sys-subsystem-net-devices-%{entry.interface}.device"],
        },
      }
    in
    let base_units = {
      "polkit.service" = {
        sections = {
          Unit = {
            Description = "Authorization Manager",
            Documentation = "man:polkit(8)",
          },
          Service = {
            Type = "notify-reload",
            BusName = "org.freedesktop.PolicyKit1",
            CapabilityBoundingSet = ["CAP_SETUID", "CAP_SETGID"],
            DeviceAllow = "/dev/null rw",
            DevicePolicy = "strict",
            ExecStart = "%{p.polkit}/lib/polkit-1/polkitd --no-debug --log-level=notice",
            User = "polkituser",
            LimitMEMLOCK = "0",
            LockPersonality = "yes",
            MemoryDenyWriteExecute = "yes",
            NoNewPrivileges = "yes",
            PrivateDevices = "yes",
            PrivateNetwork = "yes",
            PrivateTmp = "yes",
            ProtectControlGroups = "yes",
            ProtectHome = "yes",
            ProtectKernelModules = "yes",
            ProtectKernelLogs = "yes",
            ProtectKernelTunables = "yes",
            ProtectSystem = "strict",
            ProtectClock = "yes",
            ProtectHostname = "yes",
            RemoveIPC = "yes",
            RestrictAddressFamilies = ["AF_UNIX"],
            RestrictNamespaces = "yes",
            RestrictRealtime = "yes",
            RestrictSUIDSGID = "yes",
            SystemCallArchitectures = "native",
            SystemCallFilter = "@system-service",
            UMask = "0077",
            MemoryMax = "32M",
            MemorySwapMax = "32M",
            OOMPolicy = "stop",
            Restart = "on-failure",
          },
        },
        wanted_by = ["multi-user.target"],
      },
      "ModemManager.service" = {
        sections = {
          Unit = {
            Description = "Modem Manager",
            After = "polkit.service",
            Requires = "polkit.service",
            ConditionVirtualization = "!container",
          },
          Service = {
            Type = "dbus",
            BusName = "org.freedesktop.ModemManager1",
            ExecStart = "%{p.modemmanager}/sbin/ModemManager",
            StandardError = "null",
            Restart = "on-abort",
            CapabilityBoundingSet = ["CAP_SYS_ADMIN", "CAP_NET_ADMIN"],
            ProtectSystem = "true",
            ProtectHome = "true",
            PrivateTmp = "true",
            RestrictAddressFamilies = ["AF_NETLINK", "AF_UNIX", "AF_QIPCRTR"],
            NoNewPrivileges = "true",
            User = "root",
          },
        },
        wanted_by = ["multi-user.target"],
      },
      "fstrim.service" = {
        sections = {
          Unit = {
            Description = "Discard unused blocks on filesystems from /etc/fstab",
            Documentation = "man:fstrim(8)",
            ConditionVirtualization = "!container",
          },
          Service = {
            Type = "oneshot",
            ExecStart = "%{p."util-linux-bin"}/sbin/fstrim --listed-in /etc/fstab:/proc/self/mountinfo --verbose --quiet-unsupported",
            PrivateDevices = "no",
            PrivateNetwork = "yes",
            PrivateUsers = "no",
            ProtectKernelTunables = "yes",
            ProtectKernelModules = "yes",
            ProtectControlGroups = "yes",
            MemoryDenyWriteExecute = "yes",
            SystemCallFilter = "@default @file-system @basic-io @system-service",
          },
        },
      },
      "fstrim.timer" = {
        sections = {
          Unit = {
            Description = "Discard unused filesystem blocks once a week",
            Documentation = "man:fstrim",
            ConditionVirtualization = "!container",
            ConditionPathExists = "!/etc/initrd-release",
          },
          Timer = { OnCalendar = "weekly", AccuracySec = "1h", Persistent = "true", RandomizedDelaySec = "100min" },
        },
        wanted_by = ["timers.target"],
      },
      "logrotate-checkconf.service" = {
        sections = {
          Unit = { Description = "Logrotate configuration check" },
          Service = {
            Type = "oneshot",
            RemainAfterExit = "true",
            ExecStart = "%{p.logrotate}/sbin/logrotate --debug /etc/logrotate.conf",
          },
        },
        wanted_by = ["multi-user.target"],
      },
      "logrotate.service" = {
        sections = {
          Unit = {
            Description = "Logrotate Service",
            Documentation = ["man:logrotate(8)", "man:logrotate(5)"],
          },
          Service = {
            Type = "oneshot",
            ExecStart = "%{p.logrotate}/bin/logrotate /etc/logrotate.conf",
            Nice = "19",
            IOSchedulingClass = "best-effort",
            IOSchedulingPriority = "7",
            CapabilityBoundingSet = ["CAP_CHOWN", "CAP_DAC_OVERRIDE", "CAP_FOWNER", "CAP_KILL", "CAP_SETUID", "CAP_SETGID"],
            DevicePolicy = "closed",
            LockPersonality = "true",
            MemoryDenyWriteExecute = "true",
            NoNewPrivileges = "true",
            PrivateDevices = "true",
            PrivateTmp = "true",
            ProcSubset = "pid",
            ProtectClock = "true",
            ProtectControlGroups = "true",
            ProtectHome = "true",
            ProtectHostname = "true",
            ProtectKernelLogs = "true",
            ProtectKernelModules = "true",
            ProtectKernelTunables = "true",
            ProtectProc = "invisible",
            ProtectSystem = "full",
            RestrictNamespaces = "true",
            RestrictRealtime = "true",
            RestrictSUIDSGID = "false",
            SystemCallArchitectures = "native",
            SystemCallFilter = ["@system-service", "~@privileged @resources", "@chown @setuid"],
            UMask = "0027",
          },
        },
      },
      "logrotate.timer" = {
        sections.Timer = { OnCalendar = "hourly" },
        wanted_by = ["timers.target"],
      },
    }
    in
    let scx_unit =
      if cfg.scx_scheduler == "" then
        {}
      else
        {
          "scx.service" = {
            sections = {
              Unit = {
                Description = "SCX scheduler daemon",
                ConditionPathIsDirectory = "/sys/kernel/sched_ext",
                StartLimitIntervalSec = "30",
                StartLimitBurst = "2",
              },
              Service = {
                Type = "simple",
                Environment = ["SCX_SCHEDULER=%{cfg.scx_scheduler}", "SCX_FLAGS=%{cfg.scx_flags}"],
                ExecStart = "%{p.bash}/bin/bash -c 'exec %{p.scx}/bin/${SCX_SCHEDULER_OVERRIDE:-$SCX_SCHEDULER} ${SCX_FLAGS_OVERRIDE:-$SCX_FLAGS}'",
                Restart = "on-failure",
              },
            },
            wanted_by = ["multi-user.target"],
          },
        }
    in
    let address_units = cfg.static_addresses |> std.array.map address_unit |> std.array.fold_left (fun acc entry => acc & entry) {} in
    {
      output.host = {
        users.polkituser = {
          uid = 28,
          group = "polkituser",
          description = "PolKit daemon",
        },
        groups.polkituser = { gid = 990 },
        # NixOS's fixed utmp group is used by its btmp/wtmp logrotate rules.
        groups.utmp = { gid = 29 },
        packages = [p.polkit, p.modemmanager, p.scx, p.logrotate, p."util-linux-bin"],
        units = base_units & scx_unit & address_units,
        package_units = [
          { package = p.polkit, units = ["polkit-agent-helper@.service", "polkit-agent-helper.socket"] },
        ],
        wants = { "sockets.target" = ["polkit-agent-helper.socket"] },
        unit_aliases = { "dbus-org.freedesktop.ModemManager1.service" = "ModemManager.service" },
        dropins."polkit-agent-helper@.service"."onixos.conf" = m%"
          [Service]
          StandardError=journal
        "%,
        udev_packages = [p.modemmanager],
        dbus_packages = [p.polkit, p.modemmanager],
        files = {
          "polkit-1/rules.d/10-nixos.rules".text = m%"
            polkit.addAdminRule(function(action, subject) {
              return ["unix-group:wheel"];
            });

            polkit.addRule(function(action, subject) {
              if (
                subject.isInGroup("networkmanager")
                && action.id.indexOf("org.freedesktop.ModemManager") == 0
              )
                { return polkit.Result.YES; }
            });
          "%,
          "polkit-1/polkitd.conf".text = "[Polkitd]\nExpirationSeconds=300\n",
          "logrotate.conf".text = m%"
          # Global options for logrotate
          weekly
          notifempty
          missingok
          compress
          delaycompress
          rotate 4
          su root root

          /var/log/btmp {
            create 0660 root utmp
            frequency monthly
            minsize 1M
            rotate 1
          }

          /var/log/wtmp {
            create 0664 root utmp
            frequency monthly
            minsize 1M
            rotate 1
          }
        "%,
        },
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/host-extra",
        description = "Machine-level tag pieces (fstrim, logrotate, scx, polkit, ModemManager, static addresses) for OnixOS systemd hosts.",
        categories = ["system"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts only; NixOS machines get these from their tags",
          },
        ],
      },
      packages = ["polkit", "modemmanager", "scx", "logrotate", "util-linux-bin=util-linux.bin", "iproute2", "bash"],
      roles.host = {
        scx_scheduler
          | doc "scx scheduler binary name to run, or \"\" for none (perf-tuning uses scx_bpfland)."
          | String
          | default
          = "",
        scx_flags | String | default = "",
        static_addresses
          | doc "Static addresses per interface, rendered as NixOS's network-addresses-<interface>.service does."
          | Array { interface | String, addresses | Array String, gateway | String | optional }
          | default
          = [],
      },
    },

    impl = host_impl,

    tests | not_exported =
      let pkgs = {
        polkit = "polkit-pkg",
        modemmanager = "mm-pkg",
        scx = "scx-pkg",
        logrotate = "logrotate-pkg",
        "util-linux-bin" = "utillinux-pkg",
        iproute2 = "iproute2-pkg",
        bash = "bash-pkg",
      }
      in
      let test_settings = {
        scx_scheduler = "scx_bpfland",
        static_addresses = [{ interface = "enp191s0", addresses = ["10.10.10.2/24"] }],
      }
      in
      let out = (host_impl (onix.testing.mock_args { service = "host-extra", role_name = 'host, settings = test_settings, packages = pkgs })).output.host in
      [
        std.array.elem "SCX_SCHEDULER=scx_bpfland" (std.record.get "scx.service" out.units).sections.Service.Environment,
        std.array.elem "iproute2-pkg/bin/ip address add 10.10.10.2/24 dev enp191s0" (std.record.get "network-addresses-enp191s0.service" out.units).sections.Service.ExecStart,
        out.units."fstrim.timer".wanted_by == ["timers.target"],
        std.array.elem "polkit-pkg" out.dbus_packages,
        out.users.polkituser.group == "polkituser",
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
