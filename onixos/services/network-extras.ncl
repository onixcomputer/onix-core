# NetworkManager and ModemManager udev integration plus the NixOS-selected
# wpa_supplicant D-Bus service for the native NM ordinary-link design.
# NixOS's NetworkManager module defaults to no external VPN plugins; the
# current aspen2 source selects none, so this module does not synthesize one.
fun onix =>
  let supplicant_config = "pmf=1\n" in
  ({
    interface = {
      manifest = {
        name = "onix-core/network-extras",
        description = "NetworkManager and ModemManager udev rules and NetworkManager's WPA supplicant backend.",
        categories = ["networking"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS supplies package udev rules and the D-Bus WPA backend from its networking and modem modules.",
          },
        ],
      },
      packages = ["coreutils", "modemmanager", "networkmanager", "wireless-regdb", "wpa_supplicant"],
      roles.host = {},
    },

    impl = fun args =>
      let p = args.package_paths in
      {
        output.host = {
          packages = [p.wpa_supplicant],
          dbus_packages = [p.wpa_supplicant],
          udev_packages = [p.networkmanager, p.modemmanager],
          kernel.firmware = [p."wireless-regdb"],
          users.wpa_supplicant = {
            group = "wpa_supplicant",
            description = "WPA Supplicant user",
          },
          groups.wpa_supplicant = {},
          files = {
            "udev/rules.d/99-wpa-supplicant.rules".text =
              m%"
              ACTION=="add|remove", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", RUN+="/run/current-system/sw/bin/systemctl try-restart wpa_supplicant.service"
            "%
              ++ "\n",
            "wpa_supplicant/nixos.conf".text = supplicant_config,
          },
          units."wpa_supplicant.service" = {
            sections = {
              Unit = {
                Description = "WPA Supplicant instance",
                Before = "network.target",
                Wants = "network.target",
                X-Restart-Triggers = std.hash 'Sha256 supplicant_config,
              },
              Service = {
                X-StopIfChanged = "false",
                RuntimeDirectory = "wpa_supplicant",
                ExecStart = "%{p.wpa_supplicant}/bin/wpa_supplicant -s -u -Dnl80211,wext -c /etc/wpa_supplicant/imperative.conf",
                ExecStartPre = [
                  "+%{p.coreutils}/bin/touch /etc/wpa_supplicant/imperative.conf",
                  "+%{p.coreutils}/bin/chmod 664 /etc/wpa_supplicant/imperative.conf",
                  "+%{p.coreutils}/bin/chown wpa_supplicant:wpa_supplicant /etc/wpa_supplicant",
                  "+%{p.coreutils}/bin/chown wpa_supplicant:wpa_supplicant /etc/wpa_supplicant/imperative.conf",
                ],
                User = "wpa_supplicant",
                Group = "wpa_supplicant",
                AmbientCapabilities = ["CAP_NET_ADMIN", "CAP_NET_RAW"],
                BindPaths = ["/etc/wpa_supplicant", "/run/wpa_supplicant", "/proc/sys/net", "/dev/rfkill", "/run/dbus"],
                BindReadOnlyPaths = ["/nix/store", "/etc/"],
                CapabilityBoundingSet = ["CAP_NET_ADMIN", "CAP_NET_RAW"],
                DeviceAllow = ["/dev/rfkill rw"],
                IPAddressDeny = "any",
                LockPersonality = "true",
                MemoryDenyWriteExecute = "true",
                NoNewPrivileges = "true",
                PrivateDevices = "true",
                PrivateMounts = "true",
                PrivateTmp = "true",
                PrivateUsers = "false",
                ProtectClock = "true",
                ProtectControlGroups = "true",
                ProtectHome = "true",
                ProtectHostname = "true",
                ProtectKernelLogs = "true",
                ProtectKernelModules = "true",
                ProtectKernelTunables = "true",
                ProtectProc = "invisible",
                ProtectSystem = "strict",
                RemoveIPC = "true",
                RestrictAddressFamilies = ["AF_UNIX", "AF_INET", "AF_INET6", "AF_NETLINK", "AF_PACKET"],
                RestrictNamespaces = "true",
                RestrictRealtime = "true",
                RestrictSUIDSGID = "true",
                RootDirectory = "/run/wpa_supplicant",
                RootDirectoryStartOnly = "true",
                SystemCallArchitectures = "native",
                SystemCallFilter = ["@system-service", "~@keyring", "~@resources"],
                UMask = "0077",
              },
            },
            wanted_by = ["multi-user.target"],
          },
        },
      },
  }
  ) | onix.ServiceModule
