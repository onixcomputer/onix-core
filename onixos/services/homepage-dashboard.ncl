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
      packages = ["homepage-dashboard"],
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
            users."homepage-dashboard" = { group = "homepage-dashboard", description = "Homepage dashboard service user" },
            groups."homepage-dashboard" = {},
            files =
              { "homepage-dashboard/settings.yaml".text = std.serialize 'Yaml cfg.settings }
              & (if cfg.services == [] then {} else { "homepage-dashboard/services.yaml".text = std.serialize 'Yaml cfg.services })
              & (if cfg.widgets == [] then {} else { "homepage-dashboard/widgets.yaml".text = std.serialize 'Yaml cfg.widgets })
              & (if cfg.bookmarks == [] then {} else { "homepage-dashboard/bookmarks.yaml".text = std.serialize 'Yaml cfg.bookmarks }),
            units."homepage-dashboard.service" = {
              sections = {
                Unit = { Description = "Homepage Dashboard", After = "network.target" },
                Service = {
                  Type = "simple",
                  ExecStart = "%{args.package_paths."homepage-dashboard"}/bin/homepage",
                  User = "homepage-dashboard",
                  Group = "homepage-dashboard",
                  StateDirectory = "homepage-dashboard",
                  Environment = [
                    "HOMEPAGE_ALLOWED_HOSTS=%{cfg.allowed_hosts}",
                    "HOMEPAGE_CONFIG_DIR=/etc/homepage-dashboard",
                    "LOG_TARGETS=stdout",
                    "NIXPKGS_HOMEPAGE_CACHE_DIR=/var/cache/homepage-dashboard",
                  ],
                  Restart = "on-failure",
                },
              },
              wanted_by = ["multi-user.target"],
            },
            tmpfiles = ["d /var/cache/homepage-dashboard 0755 homepage-dashboard homepage-dashboard -"],
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
