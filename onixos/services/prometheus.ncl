# Prometheus server and exporters.
#
# Port of onix-core's Clan prometheus service (modules/prometheus): same
# roles, settings, defaults and NixOS output.
#   server    services.prometheus scraping the tailnet through tailscalesd
#             (localhost:9242) with this machine's own exporters merged in,
#             plus static, DNS and extra scrape jobs and HTTP probes through
#             a loopback blackbox exporter.
#   exporter  one services.prometheus.exporters.<exporter_type>.
# Both roles add the prometheus package; OnixOS installs output.packages once
# per machine, as Clan's perMachine module did.
#
# Clan read three facts from the machine's NixOS config. Here they come from
# the roles placed on the same machine (placement_facts.colocated_roles):
#   services.tailscale.enable            a role of the tailscale service
#   services.prometheus.exporters.node   an exporter role of this service whose
#   and .systemd enable                  role-level settings pick that type
# Local targets carry the machine name, which onix-core also uses as
# networking.hostName (Clan read networking.hostName).
fun onix =>
  let tailscale_service = "tailscale" in
  let tailscalesd_url = "http://localhost:9242/" in
  let blackbox_port = 9115 in
  # Clan wrote this file with pkgs.writeText and passed the store path.
  # Nickel output cannot name a store path, so it lives in /etc.
  let blackbox_config_file = "prometheus-blackbox-storage.yaml" in
  let blackbox_config =
    std.serialize
      'Json
      {
        modules.http_2xx = {
          prober = "http",
          timeout = "5s",
          http = { method = "GET", preferred_ip_protocol = "ip4" },
        },
      }
  in
  let PromDuration =
    std.contract.custom (fun label value =>
      if std.is_string value && std.string.is_match "^(0|([0-9]+(ms|[smhdwy]))+)$" value then
        'Ok value
      else
        label
        |> std.contract.label.with_message "invalid Prometheus duration (examples: 30d, 2w, 1d12h)"
        |> std.contract.blame
    )
  in
  let DnsDiscoveryJob = {
    names | doc "DNS names to query." | Array onix.NonEmptyString,
    "type" | doc "DNS record type to query." | [| 'A, 'AAAA, 'SRV |] | default = 'A,
    port | doc "Port to use for the targets." | onix.Port,
  }
  in
  # Clan built per-job lists with mapAttrsToList, which visits names in order.
  let sorted_entries = fun jobs =>
    std.record.fields jobs
    |> std.array.sort std.string.compare
    |> std.array.map (fun job => { name = job, value = jobs."%{job}" })
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/prometheus",
        description = "Prometheus server with Tailscale discovery, and Prometheus exporters.",
        categories = ["monitoring", "metrics"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "nixos",
            targets = ["nixos"],
            rationale = "Prometheus, its exporters and tailscalesd are configured through NixOS service options",
          },
        ],
      },
      packages = ["prometheus", "tailscalesd"],
      roles = {
        server = {
          enable_auto_discovery
            | doc "Scrape the targets found by discovery_method."
            | Bool
            | priority -5
            = true,
          discovery_method
            | doc "Service discovery method. 'tailscale needs a tailscale role on the same machine; 'static adds nothing beyond static_targets, which are always scraped."
            | [| 'none, 'tailscale, 'dns, 'static |]
            | priority -5
            = 'none,
          port
            | doc "Prometheus listen port, opened in the firewall."
            | onix.Port
            | priority -5
            = 9090,
          retention_time
            | doc "Metric retention period."
            | PromDuration
            | priority -5
            = "30d",
          global_config
            | doc "services.prometheus.globalConfig, e.g. { scrape_interval = \"15s\" }."
            | { .. }
            | priority -5
            = {},
          additional_scrape_configs
            | doc "Extra scrape jobs, appended after the discovered and static jobs."
            | Array { job_name | onix.NonEmptyString, .. }
            | priority -5
            = [],
          http_probe_targets
            | doc "URLs probed through a loopback blackbox exporter (job storage-coordination-health)."
            | Array onix.NonEmptyString
            | priority -5
            = [],
          rules
            | doc "Alerting rule YAML documents (services.prometheus.rules)."
            | Array String
            | priority -5
            = [],
          static_targets
            | doc "Static targets per job name, e.g. { node = [\"10.0.0.5:9100\"] }."
            | { _ : Array onix.NonEmptyString }
            | priority -5
            = {},
          dns_discovery
            | doc "DNS discovery per job name; used when discovery_method = 'dns."
            | { _ : DnsDiscoveryJob }
            | priority -5
            = {},
          extra_options
            | doc "Further services.prometheus options, passed through unchanged (Clan's freeform settings). Must not repeat options this role sets."
            | { .. }
            | priority -5
            = {},
        },
        exporter = {
          exporter_type
            | doc "services.prometheus.exporters.<name> to enable."
            | [| 'node, 'systemd, 'nginx, 'postgres, 'redis, 'blackbox, 'snmp, 'json, 'domain |],
          port
            | doc "Exporter listen port, opened in the firewall."
            | onix.Port
            | priority -5
            = 9100,
          enabled_collectors
            | doc "Collectors to enable; left unset when empty."
            | Array onix.NonEmptyString
            | priority -5
            = [],
          extra_options
            | doc "Further options of the exporter, passed through unchanged (Clan's freeform settings)."
            | { .. }
            | priority -5
            = {},
        },
      },
    },

    impl = fun args =>
      let cfg = args.settings in
      let colocated =
        args.placement_facts.colocated_roles
        |> std.array.filter (fun neighbour => neighbour.same_machine)
      in
      let local_exporter = fun wanted =>
        colocated
        |> std.array.any (fun neighbour =>
          neighbour.service == args.instance.service
          && neighbour.role_name == "exporter"
          && std.record.has_field "exporter_type" neighbour.settings
          && neighbour.settings.exporter_type == wanted
        )
      in
      args.role_name
      |> match {
        'server =>
          let machine = args.machine_name in
          let has_tailscale =
            colocated |> std.array.any (fun neighbour => neighbour.service == tailscale_service)
          in
          let tailscale_discovery = cfg.enable_auto_discovery && cfg.discovery_method == 'tailscale in
          let with_local_targets = fun local_targets job =>
            if local_targets == [] then job else job & { static_configs = local_targets }
          in
          let node_targets =
            if local_exporter 'node then
              [
                {
                  targets = ["localhost"],
                  labels = {
                    instance = machine,
                    "__meta_tailscale_device_name" = machine,
                    "__meta_tailscale_device_hostname" = machine,
                    "__meta_tailscale_device_os" = "nixos",
                    source = "local",
                  },
                },
              ]
            else
              []
          in
          let systemd_targets =
            if local_exporter 'systemd then
              [
                {
                  targets = ["localhost"],
                  labels = {
                    instance = machine,
                    "__meta_tailscale_device_name" = machine,
                    source = "local",
                  },
                },
              ]
            else
              []
          in
          # The relabelled exporter ports are fixed, as in Clan.
          let tailscale_jobs = [
            with_local_targets
              node_targets
              {
                job_name = "tailscale-node-exporter",
                http_sd_configs = [{ url = tailscalesd_url }],
                relabel_configs = [
                  { source_labels = ["__address__"], regex = "(.*)", replacement = "${1}:9100", target_label = "__address__" },
                  { source_labels = ["__meta_tailscale_device_name"], target_label = "instance" },
                  { source_labels = ["__meta_tailscale_device_os"], target_label = "os" },
                  { source_labels = ["__meta_tailscale_device_tag"], regex = "tag:(.+)", target_label = "tailscale_tag_${1}" },
                ],
              },
            with_local_targets
              systemd_targets
              {
                job_name = "tailscale-systemd-exporter",
                http_sd_configs = [{ url = tailscalesd_url }],
                relabel_configs = [
                  { source_labels = ["__address__"], regex = "(.*)", replacement = "${1}:9558", target_label = "__address__" },
                  { source_labels = ["__meta_tailscale_device_name"], target_label = "instance" },
                ],
              },
          ]
          in
          let dns_jobs =
            sorted_entries cfg.dns_discovery
            |> std.array.map (fun entry =>
              {
                job_name = "%{entry.name}-dns",
                dns_sd_configs = [
                  {
                    names = entry.value.names,
                    "type" = std.to_string entry.value."type",
                    port = entry.value.port,
                    refresh_interval = "30s",
                  },
                ],
              }
            )
          in
          let static_jobs =
            sorted_entries cfg.static_targets
            |> std.array.map (fun entry => { job_name = entry.name, static_configs = [{ targets = entry.value }] })
          in
          # Clan also returned the static jobs for discovery_method = "static",
          # on top of the static jobs it always adds; promtool rejects the
          # duplicate job names, so they are listed once.
          let discovered_jobs =
            if !cfg.enable_auto_discovery then
              []
            else
              cfg.discovery_method
              |> match {
                'tailscale => if has_tailscale then tailscale_jobs else [],
                'dns => dns_jobs,
                _ => [],
              }
          in
          let probe_jobs =
            if cfg.http_probe_targets == [] then
              []
            else
              [
                {
                  job_name = "storage-coordination-health",
                  metrics_path = "/probe",
                  params."module" = ["http_2xx"],
                  static_configs = [{ targets = cfg.http_probe_targets }],
                  relabel_configs = [
                    { source_labels = ["__address__"], target_label = "__param_target" },
                    { source_labels = ["__param_target"], target_label = "instance" },
                    { target_label = "__address__", replacement = "127.0.0.1:%{std.to_string blackbox_port}" },
                  ],
                },
              ]
          in
          let scrape_configs = discovered_jobs @ static_jobs @ cfg.additional_scrape_configs @ probe_jobs in
          {
            output = {
              nixos =
                {
                  services.prometheus =
                    {
                      enable = true,
                      port = cfg.port,
                      retentionTime = cfg.retention_time,
                      globalConfig = cfg.global_config,
                      rules = cfg.rules,
                    }
                    & (if scrape_configs == [] then {} else { scrapeConfigs = scrape_configs })
                    & cfg.extra_options,
                  networking.firewall.allowedTCPPorts = [cfg.port],
                }
                & (
                  if probe_jobs == [] then
                    {}
                  else
                    {
                      services.prometheus.exporters.blackbox = {
                        enable = true,
                        listenAddress = "127.0.0.1",
                        port = blackbox_port,
                        configFile = "/etc/%{blackbox_config_file}",
                        # The build-time check reads configFile during
                        # evaluation, which an /etc path cannot offer.
                        enableConfigCheck = false,
                      },
                      environment.etc."%{blackbox_config_file}".text = blackbox_config,
                      # A changed config changed Clan's ExecStart and so
                      # restarted the exporter; keep that.
                      systemd.services.prometheus-blackbox-exporter.restartTriggers = [blackbox_config],
                    }
                )
                & (if tailscale_discovery then { users.groups.tailscale = {} } else {})
                & (
                  if tailscale_discovery && has_tailscale then
                    {
                      systemd.services.tailscalesd = {
                        description = "Tailscale Service Discovery for Prometheus",
                        after = ["network.target", "tailscaled.service"],
                        wantedBy = ["multi-user.target"],
                        # Nickel cannot put the package path into ExecStart.
                        path = [args.packages.tailscalesd],
                        script = "exec tailscalesd --localapi --localapi_socket /var/run/tailscale/tailscaled.sock",
                        serviceConfig = {
                          Restart = "always",
                          RestartSec = 10,
                          User = "prometheus",
                          Group = "prometheus",
                          # Access to the tailscaled socket.
                          SupplementaryGroups = ["tailscale"],
                        },
                      },
                    }
                  else if tailscale_discovery then
                    {
                      warnings = [
                        "Prometheus Tailscale discovery is enabled but Tailscale is not available. Discovery will be disabled.",
                      ],
                    }
                  else
                    {}
                ),
              packages = [args.packages.prometheus],
            },
          },
        'exporter =>
          let type_name = std.to_string cfg.exporter_type in
          {
            output = {
              nixos = {
                services.prometheus.exporters."%{type_name}" =
                  { enable = true, port = cfg.port }
                  & (if cfg.enabled_collectors == [] then {} else { enabledCollectors = cfg.enabled_collectors })
                  & cfg.extra_options,
                networking.firewall.allowedTCPPorts = [cfg.port],
              },
              packages = [args.packages.prometheus],
            },
          },
      },

    tests | not_exported =
      let fake_packages = { prometheus = "prometheus-pkg", tailscalesd = "tailscalesd-pkg" } in
      let server_defaults = interface.roles.server in
      let exporter_defaults = interface.roles.exporter in
      let placed = fun service_name role_label role_settings =>
        {
          instance_name = "%{service_name}-%{role_label}",
          service = service_name,
          role_name = role_label,
          machines = ["aspen2"],
          settings = role_settings,
          same_machine = true,
        }
      in
      let tailnet = placed "tailscale" "peer" {} in
      let node_exporter = placed "prometheus" "exporter" { exporter_type = 'node } in
      let systemd_exporter = placed "prometheus" "exporter" { exporter_type = 'systemd } in
      let run = fun role_tag role_settings neighbours =>
        let mock =
          onix.testing.mock_args {
            service = "prometheus",
            role_name = role_tag,
            settings = role_settings,
            instance_name = "monitoring",
            machine_name = "aspen2",
            packages = fake_packages,
            placement_facts = {
              current = {
                instance_name = "monitoring",
                role_name = std.to_string role_tag,
                machine_name = "aspen2",
                machines = ["aspen2"],
              },
              colocated_roles = neighbours,
              role_targets = {},
            },
          }
        in
        (impl mock).output
      in
      let job_names = fun result => result.nixos.services.prometheus.scrapeConfigs |> std.array.map (fun job => job.job_name) in
      let fleet_rules = import "../../inventory/services/prometheus-rules.ncl" in
      let probe_targets = ["http://100.100.103.95:39000/health", "http://100.100.103.95:39400/nix-cache-info"] in
      let aspen2 =
        server_defaults
        & {
          discovery_method = 'tailscale,
          global_config = { scrape_interval = "15s", evaluation_interval = "15s" },
          additional_scrape_configs = [{ job_name = "prometheus", static_configs = [{ targets = ["localhost:9090"] }] }],
          http_probe_targets = probe_targets,
          rules = fleet_rules,
        }
      in
      let full = run 'server aspen2 [tailnet, node_exporter, systemd_exporter] in
      let prom = full.nixos.services.prometheus in
      let node_job = std.array.at 0 prom.scrapeConfigs in
      let systemd_job = std.array.at 1 prom.scrapeConfigs in
      let probe_job = std.array.at 3 prom.scrapeConfigs in
      let sd_unit = full.nixos.systemd.services.tailscalesd in
      let blackbox_text = full.nixos.environment.etc."prometheus-blackbox-storage.yaml".text in
      let no_tailnet = run 'server aspen2 [node_exporter, systemd_exporter] in
      let foreign_exporter = run 'server aspen2 [tailnet, placed "node-stats" "exporter" { exporter_type = 'node }] in
      let bare = (run 'server server_defaults []).nixos in
      let dns_run =
        run
          'server
          (server_defaults & { discovery_method = 'dns, dns_discovery.node = { names = ["*.monitoring.local"], port = 9100 } })
          []
      in
      let static_run = run 'server (server_defaults & { discovery_method = 'static, static_targets.node = ["10.0.0.5:9100"] }) [] in
      let extra_run = run 'server (server_defaults & { extra_options.webExternalUrl = "https://prometheus.example" }) [] in
      let node_run = run 'exporter (exporter_defaults & { exporter_type = 'node, enabled_collectors = ["systemd", "textfile"] }) [] in
      let systemd_run = run 'exporter (exporter_defaults & { exporter_type = 'systemd, port = 9558 }) [] in
      [
        # Clan defaults: discovery is chosen per instance; 30 days of retention.
        server_defaults.enable_auto_discovery,
        server_defaults.discovery_method == 'none,
        server_defaults.port == 9090,
        server_defaults.retention_time == "30d",
        exporter_defaults.port == 9100,
        exporter_defaults.enabled_collectors == [],
        # aspen2: tailnet jobs, then extra jobs, then the probes.
        job_names full == ["tailscale-node-exporter", "tailscale-systemd-exporter", "prometheus", "storage-coordination-health"],
        node_job.http_sd_configs == [{ url = "http://localhost:9242/" }],
        (std.array.first node_job.relabel_configs).replacement == "${1}:9100",
        (std.array.first systemd_job.relabel_configs).replacement == "${1}:9558",
        # The machine's own exporters join the tailnet jobs.
        node_job.static_configs == [
          {
            targets = ["localhost"],
            labels = {
              instance = "aspen2",
              "__meta_tailscale_device_name" = "aspen2",
              "__meta_tailscale_device_hostname" = "aspen2",
              "__meta_tailscale_device_os" = "nixos",
              source = "local",
            },
          },
        ],
        systemd_job.static_configs == [{ targets = ["localhost"], labels = { instance = "aspen2", "__meta_tailscale_device_name" = "aspen2", source = "local" } }],
        # Probes go through the loopback blackbox exporter.
        probe_job.metrics_path == "/probe",
        probe_job.params."module" == ["http_2xx"],
        probe_job.static_configs == [{ targets = probe_targets }],
        (std.array.at 2 probe_job.relabel_configs).replacement == "127.0.0.1:9115",
        prom.exporters.blackbox.listenAddress == "127.0.0.1",
        prom.exporters.blackbox.port == 9115,
        prom.exporters.blackbox.configFile == "/etc/prometheus-blackbox-storage.yaml",
        # The build-time check would read /etc during evaluation.
        prom.exporters.blackbox.enableConfigCheck == false,
        std.deserialize 'Json blackbox_text == { modules.http_2xx = { prober = "http", timeout = "5s", http = { method = "GET", preferred_ip_protocol = "ip4" } } },
        full.nixos.systemd.services.prometheus-blackbox-exporter.restartTriggers == [blackbox_text],
        # tailscalesd reads tailscaled's local API as prometheus with the tailscale group.
        sd_unit.after == ["network.target", "tailscaled.service"],
        sd_unit.path == ["tailscalesd-pkg"],
        sd_unit.script == "exec tailscalesd --localapi --localapi_socket /var/run/tailscale/tailscaled.sock",
        sd_unit.serviceConfig.User == "prometheus",
        sd_unit.serviceConfig.SupplementaryGroups == ["tailscale"],
        full.nixos.users.groups.tailscale == {},
        !(std.record.has_field "warnings" full.nixos),
        prom.port == 9090,
        full.nixos.networking.firewall.allowedTCPPorts == [9090],
        prom.retentionTime == "30d",
        prom.globalConfig == { scrape_interval = "15s", evaluation_interval = "15s" },
        full.packages == ["prometheus-pkg"],
        # The fleet rules reach Prometheus as one YAML document.
        std.array.length fleet_rules == 1,
        std.string.is_match "^groups:" (std.array.first fleet_rules),
        !(std.string.contains "\n---" (std.array.first fleet_rules)),
        prom.rules == fleet_rules,
        # Without tailscaled: no tailscalesd and no tailnet jobs, but a warning; the group stays.
        !(std.record.has_field "tailscalesd" no_tailnet.nixos.systemd.services),
        job_names no_tailnet == ["prometheus", "storage-coordination-health"],
        std.array.length no_tailnet.nixos.warnings == 1,
        no_tailnet.nixos.users.groups.tailscale == {},
        # Exporter roles of other services are not local targets.
        !(std.record.has_field "static_configs" (std.array.first foreign_exporter.nixos.services.prometheus.scrapeConfigs)),
        # Defaults: nothing to scrape, no blackbox exporter, no tailscale group.
        !(std.record.has_field "scrapeConfigs" bare.services.prometheus),
        !(std.record.has_field "exporters" bare.services.prometheus),
        !(std.record.has_field "environment" bare),
        !(std.record.has_field "systemd" bare),
        !(std.record.has_field "users" bare),
        dns_run.nixos.services.prometheus.scrapeConfigs == [
          {
            job_name = "node-dns",
            dns_sd_configs = [{ names = ["*.monitoring.local"], "type" = "A", port = 9100, refresh_interval = "30s" }],
          },
        ],
        # Static jobs are listed once, also for discovery_method = 'static.
        static_run.nixos.services.prometheus.scrapeConfigs == [{ job_name = "node", static_configs = [{ targets = ["10.0.0.5:9100"] }] }],
        extra_run.nixos.services.prometheus.webExternalUrl == "https://prometheus.example",
        # Exporter role: the type picks the exporter; collectors only when set.
        node_run.nixos.services.prometheus.exporters.node == { enable = true, port = 9100, enabledCollectors = ["systemd", "textfile"] },
        systemd_run.nixos.services.prometheus.exporters.systemd == { enable = true, port = 9558 },
        systemd_run.nixos.networking.firewall.allowedTCPPorts == [9558],
        systemd_run.packages == ["prometheus-pkg"],
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
