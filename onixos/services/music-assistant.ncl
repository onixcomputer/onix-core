# Music Assistant, as aspen2 runs it (machines/aspen2/configuration.nix enables
# services.music-assistant): the `mass` server with its state in
# /var/lib/music-assistant and its web port open.
fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    let cfg = args.settings in
    {
      output.host =
        {
          units."music-assistant.service" = {
            sections = {
              Unit = {
                Description = "Music Assistant",
                After = "network-online.target",
                Wants = "network-online.target",
              },
              Service = {
                Type = "simple",
                DynamicUser = "true",
                User = "music-assistant",
                Group = "music-assistant",
                StateDirectory = "music-assistant",
                Environment = [
                  "HOME=/var/lib/music-assistant",
                  "PATH=%{args.package_paths.lsof}/bin:/run/wrappers/bin:/run/current-system/sw/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin",
                ],
                EnvironmentFile = "%{args.package_paths."music-assistant-pythonpath-env"}",
                ExecStart = "%{p."music-assistant"}/bin/mass --config /var/lib/music-assistant",
                Restart = "on-failure",
                AmbientCapabilities = [""],
                CapabilityBoundingSet = [""],
                DevicePolicy = "closed",
                LockPersonality = "true",
                # Keep executable-memory support for pyopenssl/cffi and llvmlite.
                MemoryDenyWriteExecute = "false",
                BindReadOnlyPaths = ["/proc/cpuinfo"],
                ProcSubset = "all",
                ProtectClock = "true",
                ProtectControlGroups = "true",
                PrivateTmp = "true",
                ProtectHome = "true",
                ProtectHostname = "true",
                ProtectKernelLogs = "true",
                ProtectKernelModules = "true",
                ProtectKernelTunables = "true",
                ProtectProc = "invisible",
                RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_NETLINK"],
                RestrictNamespaces = "true",
                RestrictRealtime = "true",
                SystemCallArchitectures = "native",
                SystemCallFilter = ["@system-service", "~@privileged", "mbind"],
                RestrictSUIDSGID = "true",
                UMask = "0077",
              },
            },
            wanted_by = ["multi-user.target"],
          },
        }
        # Pinned NixOS defaults: UI, stream and the builtin Sendspin provider.
        & (if cfg.open_firewall then { firewall.allowed_tcp_ports = [cfg.port, 8097, 8927] } else {}),
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/music-assistant",
        description = "Music Assistant server for OnixOS systemd hosts.",
        categories = ["media"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts run the same package and state directory as services.music-assistant",
          },
        ],
      },
      packages = ["music-assistant", "lsof", "music-assistant-pythonpath-env"],
      roles.host = {
        port | onix.Port | default = 8095,
        open_firewall | Bool | default = false,
      },
    },

    impl = host_impl,
  }
  ) | onix.ServiceModule
