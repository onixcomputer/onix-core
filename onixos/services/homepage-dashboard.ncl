# Homepage dashboard web portal.
#
# Port of onix-core's Clan homepage-dashboard service
# (modules/homepage-dashboard): the role settings are the
# services.homepage-dashboard options, with Clan's defaults. The NixOS module
# opens listen_port itself when open_firewall is set.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/homepage-dashboard",
        description = "Homepage dashboard portal for service links and widgets.",
        categories = ["web", "dashboard"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "The dashboard runs through the NixOS services.homepage-dashboard module",
          },
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "OnixOS systemd hosts run the same package with its configuration directory in /etc",
          },
        ],
      },
      packages = ["homepage-dashboard", "coreutils", "bash"],
      roles.server = {
        enable
          | doc "Run the homepage dashboard."
          | Bool
          | priority -5
          = true,
        listen_port
          | doc "Port the dashboard listens on."
          | onix.Port
          | priority -5
          = 8082,
        open_firewall
          | doc "Open listen_port in the firewall."
          | Bool
          | priority -5
          = true,
        allowed_hosts
          | doc "HOMEPAGE_ALLOWED_HOSTS: comma-separated host[:port] values the dashboard answers for."
          | String
          | priority -5
          = "",
        settings
          | doc "settings.yaml contents. A value replaces this default as a whole."
          | { _ : Dyn }
          | priority -5
          = {
            title = "Dashboard",
            background = { image = "", blur = "sm", saturate = 50, brightness = 50, opacity = 50 },
          },
        services
          | doc "services.yaml contents."
          | Array Dyn
          | priority -5
          = [],
        widgets
          | doc "widgets.yaml contents."
          | Array Dyn
          | priority -5
          = [],
        bookmarks
          | doc "bookmarks.yaml contents."
          | Array Dyn
          | priority -5
          = [],
        extra_options
          | doc "Further services.homepage-dashboard options (customCSS, docker, environmentFiles, ...); Clan passed unknown role settings through."
          | { _ : Dyn }
          | priority -5
          = {},
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let has_cpu_widget =
        cfg.widgets
        |> std.array.any (fun widget =>
          std.is_record widget
          && std.record.has_field "resources" widget
          && std.is_record widget.resources
          && std.record.has_field "cpu" widget.resources
          && widget.resources.cpu == true
        )
      in
      {
        output.nixos.services.homepage-dashboard =
          {
            enable = cfg.enable,
            listenPort = cfg.listen_port,
            openFirewall = cfg.open_firewall,
            allowedHosts = cfg.allowed_hosts,
            settings = cfg.settings,
            services = cfg.services,
            widgets = cfg.widgets,
            bookmarks = cfg.bookmarks,
          }
          & cfg.extra_options,
        # NixOS renders the four YAML files into the store and points
        # HOMEPAGE_CONFIG_DIR at them; a host generation keeps them in /etc with
        # the same directory variable.
        output.host =
          {
            files = {
              "homepage-dashboard/custom.css".text =
                if std.record.has_field "customCSS" cfg.extra_options then cfg.extra_options.customCSS else "",
              "homepage-dashboard/custom.js".text =
                if std.record.has_field "customJS" cfg.extra_options then cfg.extra_options.customJS else "",
              "homepage-dashboard/bookmarks.yaml".text = std.serialize 'Yaml cfg.bookmarks,
              "homepage-dashboard/docker.yaml".text =
                std.serialize 'Yaml (if std.record.has_field "docker" cfg.extra_options then cfg.extra_options.docker else {}),
              "homepage-dashboard/kubernetes.yaml".text =
                std.serialize 'Yaml (if std.record.has_field "kubernetes" cfg.extra_options then cfg.extra_options.kubernetes else {}),
              "homepage-dashboard/proxmox.yaml".text =
                std.serialize 'Yaml (if std.record.has_field "proxmox" cfg.extra_options then cfg.extra_options.proxmox else {}),
              "homepage-dashboard/services.yaml".text = std.serialize 'Yaml cfg.services,
              "homepage-dashboard/settings.yaml".text = std.serialize 'Yaml cfg.settings,
              "homepage-dashboard/widgets.yaml".text = std.serialize 'Yaml cfg.widgets,
            },
            units."homepage-dashboard.service" = {
              sections = {
                Unit = {
                  Description = "Homepage Dashboard",
                  After = "network.target",
                  X-Restart-Triggers =
                    std.hash
                      'Sha256
                      (
                        std.serialize
                          'Json
                          {
                            settings = cfg.settings,
                            services = cfg.services,
                            widgets = cfg.widgets,
                            bookmarks = cfg.bookmarks,
                            extra_options = cfg.extra_options,
                          }
                      ),
                },
                Service = {
                  Type = "simple",
                  ExecStart = "%{args.package_paths."homepage-dashboard"}/bin/homepage",
                  # The pinned wrapper defaults PORT to 3000. The NixOS module
                  # overrides it explicitly and reads live configuration from
                  # /etc, rather than copying stale files into state.
                  ExecStartPre = "%{args.package_paths.bash}/bin/bash -c '%{args.package_paths.coreutils}/bin/rm -rf /var/cache/homepage-dashboard/*'",
                  StateDirectory = "homepage-dashboard",
                  CacheDirectory = "homepage-dashboard",
                  Environment = [
                    "PORT=%{std.to_string cfg.listen_port}",
                    "HOMEPAGE_ALLOWED_HOSTS=%{cfg.allowed_hosts}",
                    "HOMEPAGE_CONFIG_DIR=/etc/homepage-dashboard",
                    "HOME=/var/lib/homepage-dashboard",
                    "LOG_TARGETS=stdout",
                    "NIXPKGS_HOMEPAGE_CACHE_DIR=/var/cache/homepage-dashboard",
                  ],
                  Restart = "on-failure",
                  DynamicUser = "true",
                  DevicePolicy = "closed",
                  CapabilityBoundingSet = "",
                  RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_UNIX", "AF_NETLINK"],
                  DeviceAllow = "",
                  NoNewPrivileges = "true",
                  PrivateDevices = "true",
                  PrivateMounts = "true",
                  PrivateTmp = "true",
                  PrivateUsers = "true",
                  ProtectClock = "true",
                  ProtectControlGroups = "true",
                  ProtectHome = "true",
                  ProtectKernelLogs = "true",
                  ProtectKernelModules = "true",
                  ProtectKernelTunables = "true",
                  ProtectSystem = "strict",
                  LockPersonality = "true",
                  RemoveIPC = "true",
                  RestrictNamespaces = "true",
                  RestrictRealtime = "true",
                  RestrictSUIDSGID = "true",
                  SystemCallArchitectures = "native",
                  SystemCallFilter = ["@system-service", "~@resources"],
                  ProtectProc = "invisible",
                  ProtectHostname = "true",
                  UMask = "0077",
                  ProcSubset = if has_cpu_widget then "all" else "pid",
                },
              },
              wanted_by = ["multi-user.target"],
            },
          }
          & (if cfg.open_firewall then { firewall.allowed_tcp_ports = [cfg.listen_port] } else {}),
      },

    tests | not_exported =
      let defaults = interface.roles.server in
      let run_output = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "homepage-dashboard",
              role_name = 'server,
              settings = defaults & overrides,
            }
          )
        ).output
      in
      let run = fun overrides => (run_output overrides).nixos.services.homepage-dashboard in
      let out = run {} in
      [
        out.enable,
        out.listenPort == 8082,
        out.openFirewall,
        out.allowedHosts == "",
        out.settings.title == "Dashboard",
        out.settings.background.saturate == 50,
        out.services == [] && out.widgets == [] && out.bookmarks == [],
        # snake_case settings map onto the NixOS option names.
        (run { listen_port = 9000 }).listenPort == 9000,
        !(run { open_firewall = false }).openFirewall,
        (run { allowed_hosts = "localhost:8082,home.blr.dev" }).allowedHosts == "localhost:8082,home.blr.dev",
        !(std.record.has_field "listen_port" out),
        # A settings record replaces Clan's default settings instead of merging into them.
        !(std.record.has_field "background" (run { settings = { title = "Onix" } }).settings),
        (run { widgets = [{ search = { provider = "duckduckgo" } }] }).widgets == [{ search = { provider = "duckduckgo" } }],
        (run { extra_options.customCSS = "body { }" }).customCSS == "body { }",
        !(std.record.has_field "customCSS" out),
        # The NixOS module opens the port; this module emits nothing else.
        std.record.fields (run_output {}).nixos == ["services"],
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
