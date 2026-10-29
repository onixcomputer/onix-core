# Loki log store with a co-located Grafana Alloy shipper.
#
# Port of onix-core's Clan loki service (modules/loki), server role plus the
# service's per-machine packages: freeform services.loki configuration, the
# HTTP port in the firewall, and Grafana Alloy reading the systemd journal and
# extra files from /etc/alloy/config.alloy, rendered byte for byte like
# Clan's mkAlloyConfig. Clan's `alloy` role (a shipper without a server) is
# used by no instance and is not ported.
fun onix =>
  let lines = fun parts => std.string.join "\n" parts in
  let AlloyIdentifier =
    std.contract.from_predicate (fun value =>
      std.is_string value && std.string.is_match "^[A-Za-z_][A-Za-z0-9_]*$" value
    )
  in
  let FileScrape = {
    name | doc "Alloy component label; must be an Alloy identifier." | AlloyIdentifier,
    path | doc "Path or glob of the files to tail." | onix.Path,
    labels | doc "Static labels added to every line." | { _ : String } | optional,
  }
  in
  # Clan's mkFileScrapeBlock: labels in key order, one per line.
  let file_scrape_block = fun scrape =>
    let labels =
      (if std.record.has_field "labels" scrape then scrape.labels else {})
      |> std.record.to_array
      |> std.array.sort (fun left right => std.string.compare left.field right.field)
      |> std.array.map (fun label => "%{label.field} = \"%{label.value}\",")
    in
    lines [
      "local.file_match \"%{scrape.name}\" {",
      "  path_targets = [{",
      "    __path__ = \"%{scrape.path}\",",
      "    %{std.string.join "\n    " labels}",
      "  }]",
      "}",
      "",
      "loki.source.file \"%{scrape.name}\" {",
      "  targets    = local.file_match.%{scrape.name}.targets",
      "  forward_to = [loki.write.default.receiver]",
      "}",
      "",
    ]
  in
  # Clan's mkAlloyConfig: push target, journal source, then file scrapes.
  let alloy_config = fun cfg hostname =>
    lines [
      "loki.write \"default\" {",
      "  endpoint {",
      "    url = \"%{cfg.loki_url}/loki/api/v1/push\"",
      "  }",
      "}",
      "",
      "loki.relabel \"journal\" {",
      "  forward_to = []",
      "  rule {",
      "    source_labels = [\"__journal__systemd_unit\"]",
      "    target_label  = \"unit\"",
      "  }",
      "  rule {",
      "    source_labels = [\"__journal__hostname\"]",
      "    target_label  = \"hostname\"",
      "  }",
      "}",
      "",
      "loki.source.journal \"systemd\" {",
      "  forward_to    = [loki.write.default.receiver]",
      "  relabel_rules = loki.relabel.journal.rules",
      "  max_age       = \"12h\"",
      "  labels        = {",
      "    job  = \"systemd-journal\",",
      "    host = \"%{hostname}\",",
      "  }",
      "}",
      "",
      cfg.additional_file_scrapes |> std.array.map file_scrape_block |> std.string.join "\n",
      cfg.alloy_extra_config,
      "",
    ]
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/loki",
        description = "Loki log store with a co-located Grafana Alloy journal shipper.",
        categories = ["monitoring", "logs"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Loki and Alloy run through the NixOS services.loki and services.alloy modules",
          },
        ],
      },
      # `loki` is nixpkgs' C++ Loki library (0.1.7), not Grafana Loki. Clan's
      # perMachine installs it, so it stays for parity; services.loki installs
      # grafana-loki itself.
      packages = ["loki", "grafana-alloy"],
      roles.server = {
        enable_alloy
          | doc "Run Grafana Alloy next to Loki, shipping the journal and file scrapes to it."
          | Bool
          | priority -5
          = true,
        configuration
          | doc "Loki configuration (services.loki.configuration)."
          | { _ : Dyn }
          | priority -5
          = {},
        loki_url
          | doc "Loki base URL the co-located Alloy pushes to."
          | onix.Url
          | priority -5
          = "http://localhost:3100",
        additional_file_scrapes
          | doc "Files Alloy tails besides the journal."
          | Array FileScrape
          | priority -5
          = [],
        alloy_extra_config
          | doc "Raw Alloy configuration appended to the generated config."
          | String
          | priority -5
          = "",
        extra_options
          | doc "Further services.loki options; Clan passed unknown role settings to services.loki."
          | { _ : Dyn }
          | priority -5
          = {},
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let http_listen_port =
        if std.record.has_field "server" cfg.configuration
        && std.record.has_field "http_listen_port" cfg.configuration.server then
          cfg.configuration.server.http_listen_port
        else
          3100
      in
      {
        output.nixos =
          {
            services.loki = { enable = true, configuration = cfg.configuration } & cfg.extra_options,
            networking.firewall.allowedTCPPorts = [http_listen_port],
            environment.systemPackages = [args.packages.loki, args.packages.grafana-alloy],
          }
          & (
            if cfg.enable_alloy then
              {
                services.alloy.enable = true,
                # Clan used config.networking.hostName, which equals the
                # machine name on every onix-core machine.
                environment.etc."alloy/config.alloy".text = alloy_config cfg args.machine_name,
              }
            else
              {}
          ),
      },

    tests | not_exported =
      let defaults = interface.roles.server in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "loki",
              role_name = 'server,
              settings = defaults & overrides,
              instance_name = "loki-blr",
              machine_name = "aspen2",
              packages = { loki = "loki-pkg", grafana-alloy = "alloy-pkg" },
            }
          )
        ).output.nixos
      in
      let alloy_text = fun nixos => nixos.environment.etc."alloy/config.alloy".text in
      # Clan's /etc/alloy/config.alloy on aspen2, up to the journal source.
      let expected_head = m%"
        loki.write "default" {
          endpoint {
            url = "http://localhost:3100/loki/api/v1/push"
          }
        }

        loki.relabel "journal" {
          forward_to = []
          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }
          rule {
            source_labels = ["__journal__hostname"]
            target_label  = "hostname"
          }
        }

        loki.source.journal "systemd" {
          forward_to    = [loki.write.default.receiver]
          relabel_rules = loki.relabel.journal.rules
          max_age       = "12h"
          labels        = {
            job  = "systemd-journal",
            host = "aspen2",
          }
        }
      "%
      in
      let expected_varlogs = m%"
        local.file_match "varlogs" {
          path_targets = [{
            __path__ = "/var/log/*.log",
            job = "varlogs",
          }]
        }

        loki.source.file "varlogs" {
          targets    = local.file_match.varlogs.targets
          forward_to = [loki.write.default.receiver]
        }
      "%
      in
      let out = run { additional_file_scrapes = [{ name = "varlogs", path = "/var/log/*.log", labels = { job = "varlogs" } }] } in
      [
        # Byte-identical to the Clan-built etc-alloy-config.alloy of aspen2.
        alloy_text out == expected_head ++ "\n\n" ++ expected_varlogs ++ "\n\n\n",
        alloy_text (run {}) == expected_head ++ "\n\n\n\n",
        alloy_text (run { alloy_extra_config = "logging { level = \"warn\" }" }) == expected_head
        ++ "\n\n\n"
        ++ "logging { level = \"warn\" }"
        ++ "\n",
        # Labels in key order, one per line; no labels leaves Clan's blank line.
        std.string.contains
          "    __path__ = \"/srv/app/*.log\",\n    env = \"prod\",\n    job = \"app\",\n  }]"
          (alloy_text (run { additional_file_scrapes = [{ name = "app", path = "/srv/app/*.log", labels = { job = "app", env = "prod" } }] })),
        std.string.contains
          "    __path__ = \"/srv/app/*.log\",\n    \n  }]"
          (alloy_text (run { additional_file_scrapes = [{ name = "app", path = "/srv/app/*.log" }] })),
        std.string.contains
          "url = \"http://loki.example:3100/loki/api/v1/push\""
          (alloy_text (run { loki_url = "http://loki.example:3100" })),
        out.services.alloy.enable,
        !(std.record.has_field "alloy" (run { enable_alloy = false }).services),
        !(std.record.has_field "etc" (run { enable_alloy = false }).environment),
        out.services.loki.enable,
        (run { configuration.auth_enabled = false }).services.loki.configuration == { auth_enabled = false },
        out.networking.firewall.allowedTCPPorts == [3100],
        (run { configuration.server.http_listen_port = 3200 }).networking.firewall.allowedTCPPorts == [3200],
        out.environment.systemPackages == ["loki-pkg", "alloy-pkg"],
        (run { extra_options.dataDir = "/srv/loki" }).services.loki.dataDir == "/srv/loki",
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
