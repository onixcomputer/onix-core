# inventory/tags/docker.nix for OnixOS systemd hosts: the daemon as aspen2 runs it
# (overlay2 on /var/lib/docker, journald logs, live-restore, the docker group on
# /run/docker.sock), the API socket, weekly pruning, and the sysctls containers
# expect. The daemon uses the pinned package's containerd/runc/iptables wrappers
# and the AppArmor parser to load its default container profile.
fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    let daemon_config = m%"
      {
        "data-root": "/var/lib/docker",
        "default-address-pools": [
          {
            "base": "172.30.0.0/16",
            "size": 24
          }
        ],
        "dns": [
          "1.1.1.1",
          "8.8.8.8"
        ],
        "experimental": true,
        "group": "docker",
        "hosts": [
          "fd://"
        ],
        "insecure-registries": [],
        "live-restore": true,
        "log-driver": "journald",
        "log-opts": {
          "tag": "{{.Name}}/{{.ID}}"
        },
        "registry-mirrors": [
          "https://mirror.gcr.io"
        ],
        "storage-driver": "overlay2",
        "userland-proxy": false
      }
    "%
    in
    {
      output.host = {
        packages = [p.docker, p."docker-compose", p."docker-buildx", p."docker-credential-helpers", p.dive, p.lazydocker, p.ctop, p."podman-tui"],
        kernel.modules = ["overlay", "br_netfilter"],
        files."docker/daemon.json".text = daemon_config,
        units = {
          "docker.socket" = {
            sections = {
              Unit = { Description = "Docker Socket for the API" },
              Socket = {
                ListenStream = "/run/docker.sock",
                SocketMode = "0660",
                SocketUser = "root",
                SocketGroup = "docker",
              },
            },
            wanted_by = ["sockets.target"],
          },
          "docker.service" = {
            sections = {
              Unit = {
                Description = "Docker Application Container Engine",
                Documentation = "https://docs.docker.com",
                After = "network-online.target nss-lookup.target docker.socket time-set.target",
                Wants = "network-online.target",
                Requires = "docker.socket",
                StartLimitBurst = "3",
                StartLimitIntervalSec = "60",
              },
              Service = {
                Type = "notify",
                Environment = "PATH=%{p.kmod}/bin:%{p.coreutils}/bin:%{p."apparmor-parser"}/bin",
                # containerd checks this absolute path and caches a negative
                # result; PATH alone makes Docker silently omit OCI confinement.
                ExecStartPre = [
                  "%{p.coreutils}/bin/mkdir -p /sbin",
                  "%{p.coreutils}/bin/ln -sfn %{p."apparmor-parser"}/bin/apparmor_parser /sbin/apparmor_parser",
                ],
                ExecStart = "%{p.docker}/bin/dockerd --config-file=/etc/docker/daemon.json",
                ExecReload = "%{p.procps}/bin/kill -s HUP $MAINPID",
                TimeoutStartSec = "0",
                RestartSec = "5s",
                Restart = "on-failure",
                LimitNPROC = "infinity",
                LimitCORE = "infinity",
                TasksMax = "infinity",
                Delegate = "yes",
                KillMode = "process",
                OOMScoreAdjust = "-500",
              },
            },
            wanted_by = ["multi-user.target"],
          },
          "docker-gc.service" = {
            sections = {
              Unit = { Description = "Docker garbage collection" },
              Service = {
                Type = "oneshot",
                ExecStart = "%{p.docker}/bin/docker system prune -af --volumes",
              },
            },
          },
          "docker-gc.timer" = {
            sections = {
              Unit = { Description = "Docker garbage collection timer" },
              Timer = { OnCalendar = "weekly", Persistent = "true" },
            },
            wanted_by = ["timers.target"],
          },
          "docker-prune.service" = {
            sections = {
              Unit = {
                Description = "Prune docker resources",
                After = "docker.service",
                Requires = "docker.service",
                X-StopOnRemoval = "false",
              },
              Service = {
                Type = "oneshot",
                ExecStart = "%{p.docker}/bin/docker system prune -f --all --volumes",
                X-RestartIfChanged = "false",
              },
            },
          },
          "docker-prune.timer" = {
            sections.Timer = { OnCalendar = "weekly", Persistent = "true", RandomizedDelaySec = "0" },
            wanted_by = ["timers.target"],
          },
        },
        environment = { DOCKER_BUILDKIT = "1", BUILDKIT_PROGRESS = "auto" },
        tmpfiles = ["d /root/.docker 0700 root root -", "f /root/.docker/config.json 0600 root root - {}"],
        sysctl = {
          "net.bridge.bridge-nf-call-iptables" = "1",
          "net.bridge.bridge-nf-call-ip6tables" = "1",
          "net.ipv4.ip_forward" = "1",
          "net.ipv6.conf.all.forwarding" = "1",
        },
        # networking.firewall.trustedInterfaces = [ "docker0" ].
        firewall.trusted_interfaces = ["docker0"],
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/docker",
        description = "The docker tag of onix-core's machines (daemon, socket, pruning, container sysctls) for OnixOS systemd hosts.",
        categories = ["containers"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts only; NixOS machines get this from inventory/tags/docker.nix",
          },
        ],
      },
      packages = ["docker", "docker-compose", "docker-buildx", "docker-credential-helpers", "dive", "lazydocker", "ctop", "podman-tui", "coreutils", "kmod", "procps", "apparmor-parser"],
      roles.host = {},
    },

    impl = host_impl,
  }
  ) | onix.ServiceModule
