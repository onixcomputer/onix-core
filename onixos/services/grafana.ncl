# Grafana dashboards for the monitoring stack.
#
# Port of onix-core's Clan grafana service (modules/grafana): the server role
# plus the service's per-machine part. Freeform grafana.ini settings, the
# Prometheus datasource, dashboard and notifier provisioning, the admin
# password and secret key read through Grafana's $__file{} provider from the
# per-machine artifact `grafana` (Clan's generator of the same name), the
# HTTP port in the firewall, and Grafana with onix-core's BLAKE3-checked
# email templates (modules/grafana/package.nix, exposed as onix-core-grafana
# by the sidecar grafana.nix).
fun onix =>
  # settings.<section>.<key>, or the NixOS default when unset.
  let ini_value = fun settings section key fallback =>
    if std.record.has_field section settings
    && std.record.has_field key settings."%{section}" then
      settings."%{section}"."%{key}"
    else
      fallback
  in
  let non_empty = fun values => std.array.length values > 0 in
  # lib.generators.toINI, which NixOS uses for grafana.ini: strings verbatim,
  # lists space-separated, everything else through to_string.
  let _ini_value = fun value =>
    if std.is_string value then
      value
    else if std.typeof value == 'Enum then
      std.to_string value
    else if std.typeof value == 'Array then
      value |> std.array.map std.to_string |> std.string.join " "
    else
      std.to_string value
  in
  let wire_secret = fun secret_file =>
    onix.artifact_wiring {
      artifact = "grafana",
      file = secret_file,
      nixos_option = "services.grafana.settings.security.%{secret_file}",
      value = "$__file{__PATH__}",
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/grafana",
        description = "Grafana dashboards with a provisioned Prometheus datasource.",
        categories = ["monitoring", "observability"],
      },
      portability = {
        status = 'platform_specific,
        requires.typed_namespaces = ["artifacts", "artifact_wiring"],
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Grafana runs through the NixOS services.grafana module",
          },
        ],
      },
      packages = ["onix-core-grafana", "coreutils"],
      roles.server = {
        enable_prometheus_integration
          | doc "Provision Prometheus as the default datasource."
          | Bool
          | priority -5
          = true,
        prometheus_url
          | doc "URL of the Prometheus datasource; http://localhost:9090 when unset."
          | onix.Url
          | optional,
        settings
          | doc "Grafana configuration (services.grafana.settings), one record per grafana.ini section."
          | { _ : { .. } }
          | priority -5
          = {},
        additional_datasources
          | doc "Datasources provisioned after the Prometheus datasource."
          | Array { name | onix.NonEmptyString, type | onix.NonEmptyString, .. }
          | priority -5
          = [],
        dashboards
          | doc "Dashboard providers (services.grafana.provision.dashboards.settings.providers)."
          | Array { .. }
          | priority -5
          = [],
        notifiers
          | doc m%"
            Notification channels (services.grafana.provision.notifiers). NixOS
            removed that option with Grafana 11, so a non-empty list fails NixOS
            evaluation, as it does under Clan.
          "%
          | Array { .. }
          | priority -5
          = [],
        extra_options
          | doc "Further services.grafana options; Clan passed unknown role settings to services.grafana."
          | { _ : Dyn }
          | priority -5
          = {},
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let grafana_package = args.packages.onix-core-grafana in
      let grafana_path = args.package_paths."onix-core-grafana" in
      let prometheus_datasource = {
        name = "Prometheus",
        type = "prometheus",
        access = "proxy",
        url = if std.record.has_field "prometheus_url" cfg then cfg.prometheus_url else "http://localhost:9090",
        isDefault = true,
        jsonData.timeInterval = "5s",
      }
      in
      let datasource_list =
        (if cfg.enable_prometheus_integration then [prometheus_datasource] else [])
        @ cfg.additional_datasources
      in
      let provisioned =
        cfg.enable_prometheus_integration
        || non_empty datasource_list
        || non_empty cfg.dashboards
        || non_empty cfg.notifiers
      in
      let provision_config =
        {
          enable = true,
          # Clan always defines this; null keeps NixOS's empty provider list.
          dashboards.settings =
            if non_empty cfg.dashboards then
              { apiVersion = 1, providers = cfg.dashboards }
            else
              null,
        }
        & (
          if non_empty datasource_list then
            { datasources.settings = { apiVersion = 1, datasources = datasource_list, deleteDatasources = [] } }
          else
            {}
        )
        & (if non_empty cfg.notifiers then { notifiers = cfg.notifiers } else {})
      in
      {
        output =
          {
            nixos =
              {
                services.grafana =
                  { enable = true, package = grafana_package, settings = cfg.settings }
                  & (if provisioned then { provision = provision_config } else {})
                  & cfg.extra_options,
                environment.systemPackages = [grafana_package],
                networking.firewall.allowedTCPPorts = [ini_value cfg.settings "server" "http_port" 3000],
              }
              & (
                if ini_value cfg.settings "server" "protocol" "http" == "https" then
                  { users.users.grafana.extraGroups = ["nginx"] }
                else
                  {}
              ),
            artifact_wiring = [wire_secret "admin_password", wire_secret "secret_key"],
            # NixOS renders the settings into an ini file and passes it with
            # -config; a host generation keeps it in /etc and hands the two
            # secrets to Grafana through its __FILE variables, as NixOS's
            # `$__file` does.
            host =
              let ini_sections =
                cfg.settings
                |> std.record.fields
                |> std.array.map (fun section_name =>
                  let section = std.record.get section_name cfg.settings in
                  "[%{section_name}]\n"
                  ++ (
                    section
                    |> std.record.fields
                    |> std.array.map (fun key => "%{key} = %{_ini_value (std.record.get key section)}")
                    |> std.string.join "\n"
                  )
                )
                |> std.string.join "\n\n"
              in
              let secrets = ["/run/artifacts/grafana/admin_password", "/run/artifacts/grafana/secret_key"] in
              {
                users.grafana = { group = "grafana", description = "Grafana service user" },
                groups.grafana = {},
                files =
                  { "grafana.ini".text = ini_sections ++ "\n" }
                  & (
                    if provisioned then
                      {
                        "grafana/provisioning/datasources/datasources.yaml".text =
                          std.serialize 'Yaml (provision_config.datasources.settings)
                          ++ "",
                      }
                      & (
                        if non_empty cfg.dashboards then
                          { "grafana/provisioning/dashboards/dashboards.yaml".text = std.serialize 'Yaml provision_config.dashboards.settings }
                        else
                          {}
                      )
                    else
                      {}
                  ),
                units."grafana.service" = {
                  sections = {
                    Unit = {
                      Description = "Grafana Service Daemon",
                      After = "network-online.target",
                      Wants = "network-online.target",
                    },
                    Service = {
                      Type = "simple",
                      # NixOS links the package's conf and public into the data
                      # directory and runs Grafana with that as its homepath; both
                      # links are needed, because public carries the email templates.
                      ExecStartPre = [
                        "%{args.package_paths.coreutils}/bin/ln -fs %{grafana_path}/share/grafana/conf /var/lib/grafana/conf",
                        "%{args.package_paths.coreutils}/bin/ln -fs %{grafana_path}/share/grafana/public /var/lib/grafana/public",
                      ],
                      ExecStart = "%{grafana_path}/bin/grafana server -homepath /var/lib/grafana -config /etc/grafana.ini",
                      User = "grafana",
                      Group = "grafana",
                      WorkingDirectory = "/var/lib/grafana",
                      StateDirectory = "grafana",
                      RuntimeDirectory = "grafana",
                      RuntimeDirectoryMode = "0755",
                      Environment = [
                        "GF_SECURITY_ADMIN_PASSWORD__FILE=%{std.array.first secrets}",
                        "GF_SECURITY_SECRET_KEY__FILE=%{std.array.last secrets}",
                        "GF_PATHS_PROVISIONING=/etc/grafana/provisioning",
                      ],
                      Restart = "on-failure",
                      PrivateTmp = "true",
                      ProtectHome = "true",
                      ProtectSystem = "full",
                      NoNewPrivileges = "true",
                      UMask = "0027",
                      RestrictAddressFamilies = ["AF_INET", "AF_INET6", "AF_UNIX"],
                    },
                  },
                  wanted_by = ["multi-user.target"],
                },
                firewall.allowed_tcp_ports = [ini_value cfg.settings "server" "http_port" 3000],
              }
              & (
                if ini_value cfg.settings "server" "protocol" "http" == "https" then
                  { users.grafana.extra_groups = ["nginx"] }
                else
                  {}
              ),
          }
          & onix.artifact_declaration {
            name = "grafana",
            files = {
              admin_password = onix.artifact_file { owner = "grafana", group = "grafana", mode = "0400" },
              secret_key = onix.artifact_file { owner = "grafana", group = "grafana", mode = "0400" },
            },
            prompts.admin_password.description = "Grafana admin password",
            generator_script = m%"
              cat "$prompts"/admin_password > "$out"/admin_password
              # Generate a random secret key if not provided
              if [ ! -f "$out"/secret_key ]; then
                dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$out"/secret_key
              fi
            "%,
            description = "Grafana admin password and secret key for %{args.machine_name}",
          },
      },

    tests | not_exported =
      let defaults = interface.roles.server in
      let run = fun overrides =>
        (
          impl (
            onix.testing.mock_args {
              service = "grafana",
              role_name = 'server,
              settings = defaults & overrides,
              machine_name = "aspen2",
              packages = { onix-core-grafana = "grafana-pkg" },
            }
          )
        ).output
      in
      let datasources_of = fun output =>
        output.nixos.services.grafana.provision.datasources.settings.datasources
      in
      let out = run {} in
      let grafana = out.nixos.services.grafana in
      let prometheus = std.array.first (datasources_of out) in
      let artifact = out.artifacts.grafana in
      [
        # Clan default: Prometheus on localhost is the only, default datasource.
        std.array.length (datasources_of out) == 1,
        prometheus.url == "http://localhost:9090",
        prometheus.isDefault,
        prometheus.jsonData.timeInterval == "5s",
        (std.array.first (datasources_of (run { prometheus_url = "http://prom.example:9090" }))).url == "http://prom.example:9090",
        (
          datasources_of (run { additional_datasources = [{ name = "Loki", type = "loki", url = "http://localhost:3100" }] })
          |> std.array.map (fun datasource => datasource.name)
        ) == ["Prometheus", "Loki"],
        grafana.provision.dashboards.settings == null,
        # NixOS removed provision.notifiers: even an empty definition fails evaluation.
        !(std.record.has_field "notifiers" grafana.provision),
        !(std.record.has_field "provision" (run { enable_prometheus_integration = false }).nixos.services.grafana),
        (
          let provision =
            (
              run {
                enable_prometheus_integration = false,
                dashboards = [{ name = "local", options.path = "/var/lib/grafana/dashboards" }],
              }
            ).nixos.services.grafana.provision
          in
          provision.dashboards.settings.providers == [{ name = "local", options.path = "/var/lib/grafana/dashboards" }]
          && !(std.record.has_field "datasources" provision)
        ),
        # Freeform grafana.ini settings reach services.grafana.settings unchanged.
        (run { settings.server.domain = "grafana.local" }).nixos.services.grafana.settings.server.domain == "grafana.local",
        # The firewall follows server.http_port, NixOS's default 3000 when unset.
        out.nixos.networking.firewall.allowedTCPPorts == [3000],
        (run { settings.server.http_port = 3300 }).nixos.networking.firewall.allowedTCPPorts == [3300],
        !(std.record.has_field "users" out.nixos),
        (run { settings.server.protocol = "https" }).nixos.users.users.grafana.extraGroups == ["nginx"],
        grafana.package == "grafana-pkg",
        out.nixos.environment.systemPackages == ["grafana-pkg"],
        (run { extra_options.dataDir = "/srv/grafana" }).nixos.services.grafana.dataDir == "/srv/grafana",
        # Artifact named and shaped like Clan's per-machine generator.
        std.record.fields out.artifacts == ["grafana"],
        !(std.record.has_field "shared" artifact),
        std.record.fields artifact.files == ["admin_password", "secret_key"],
        std.record.fields artifact.files
        |> std.array.all (fun name =>
          let file = artifact.files."%{name}" in
          file.secret && file.owner == "grafana" && file.group == "grafana" && file.mode == "0400"
        ),
        std.record.fields artifact.prompts == ["admin_password"],
        std.string.contains "base64 > \"$out\"/secret_key" artifact.generator_script,
        (out.artifact_wiring |> std.array.map (fun wiring => wiring.nixos_option)) == ["services.grafana.settings.security.admin_password", "services.grafana.settings.security.secret_key"],
        out.artifact_wiring
        |> std.array.all (fun wiring => wiring.artifact == "grafana" && wiring.value == "$__file{__PATH__}"),
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
