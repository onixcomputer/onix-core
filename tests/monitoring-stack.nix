# VM test: full monitoring stack — Prometheus, Grafana, Loki, Promtail.
#
# Multi-machine test mirroring the actual deployment topology:
#   monitor: Prometheus + Grafana + Loki (like aspen1 with 'monitoring' tag)
#   target:  node exporter + Promtail shipping to monitor (like any tagged machine)
{ pkgs, ... }:
let
  grafanaPort = 3000;
  prometheusPort = 9090;
  lokiPort = 3100;
  nodeExporterPort = 9100;
in
pkgs.testers.runNixOSTest {
  name = "monitoring-stack";
  skipLint = true;

  nodes.monitor = _: {
    virtualisation.graphics = false;
    virtualisation.memorySize = 2048;

    environment.systemPackages = [ pkgs.jq ];

    services = {
      # Prometheus
      prometheus = {
        enable = true;
        port = prometheusPort;
        globalConfig = {
          scrape_interval = "2s";
          evaluation_interval = "2s";
        };
        scrapeConfigs = [
          {
            job_name = "prometheus";
            static_configs = [ { targets = [ "localhost:${toString prometheusPort}" ]; } ];
          }
          {
            job_name = "node";
            static_configs = [
              {
                targets = [
                  "localhost:${toString nodeExporterPort}"
                  "target:${toString nodeExporterPort}"
                ];
              }
            ];
          }
        ];
        # Local node exporter
        exporters.node = {
          enable = true;
          port = nodeExporterPort;
          enabledCollectors = [
            "systemd"
            "cpu"
            "meminfo"
          ];
        };
      };

      # Grafana with Prometheus datasource
      grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "0.0.0.0";
            http_port = grafanaPort;
          };
          security = {
            admin_user = "admin";
            admin_password = "testpass";
            secret_key = "vm-test-secret-key-not-for-production";
          };
          analytics.reporting_enabled = false;
        };
        provision = {
          enable = true;
          datasources.settings = {
            apiVersion = 1;
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://localhost:${toString prometheusPort}";
                isDefault = true;
              }
              {
                name = "Loki";
                type = "loki";
                access = "proxy";
                url = "http://localhost:${toString lokiPort}";
              }
            ];
          };
        };
      };

      # Loki
      loki = {
        enable = true;
        configuration = {
          auth_enabled = false;
          server.http_listen_port = lokiPort;
          common = {
            instance_addr = "127.0.0.1";
            path_prefix = "/var/lib/loki";
            storage.filesystem = {
              chunks_directory = "/var/lib/loki/chunks";
              rules_directory = "/var/lib/loki/rules";
            };
            replication_factor = 1;
            ring.kvstore.store = "inmemory";
          };
          schema_config.configs = [
            {
              from = "2020-10-24";
              store = "tsdb";
              object_store = "filesystem";
              schema = "v13";
              index = {
                prefix = "index_";
                period = "24h";
              };
            }
          ];
        };
      };
    };

    networking.firewall.allowedTCPPorts = [
      grafanaPort
      prometheusPort
      lokiPort
      nodeExporterPort
    ];
  };

  nodes.target = _: {
    virtualisation.graphics = false;

    # Node exporter
    services.prometheus.exporters.node = {
      enable = true;
      port = nodeExporterPort;
      enabledCollectors = [
        "systemd"
        "cpu"
        "meminfo"
      ];
    };

    # Promtail shipping to Loki on monitor
    services.promtail = {
      enable = true;
      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };
        positions.filename = "/var/cache/promtail/positions.yaml";
        clients = [
          { url = "http://monitor:${toString lokiPort}/loki/api/v1/push"; }
        ];
        scrape_configs = [
          {
            job_name = "systemd-journal";
            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = "target";
              };
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };

    systemd.tmpfiles.rules = [
      "d '/var/cache/promtail' 0700 promtail promtail - -"
    ];

    networking.firewall.allowedTCPPorts = [
      nodeExporterPort
      9080
    ];
  };

  testScript = ''
    import json

    start_all()

    # --- Prometheus ---
    monitor.wait_for_unit("prometheus.service")
    monitor.wait_for_open_port(${toString prometheusPort})
    monitor.succeed("curl -sf http://localhost:${toString prometheusPort}/-/healthy")

    # --- Node exporters ---
    monitor.wait_for_open_port(${toString nodeExporterPort})
    target.wait_for_unit("prometheus-node-exporter.service")
    target.wait_for_open_port(${toString nodeExporterPort})

    # Prometheus can reach the target's exporter
    monitor.wait_until_succeeds(
        "curl -sf http://target:${toString nodeExporterPort}/metrics | grep node_cpu_seconds_total"
    )

    # Wait for all targets to be scraped (3 = prometheus self + 2 node exporters)
    monitor.wait_until_succeeds(
        "curl -sf http://localhost:${toString prometheusPort}/api/v1/targets "
        "| jq -e '[.data.activeTargets[] | select(.health == \"up\")] | length >= 3'",
        30,
    )

    # --- Grafana ---
    monitor.wait_for_unit("grafana.service")
    monitor.wait_for_open_port(${toString grafanaPort})

    # Health check
    monitor.succeed("curl -sf http://localhost:${toString grafanaPort}/api/health")

    # Auth works
    health = json.loads(
        monitor.succeed(
            "curl -sf -u admin:testpass http://localhost:${toString grafanaPort}/api/org"
        )
    )
    assert health["name"] == "Main Org.", f"Unexpected org: {health}"

    # Datasources provisioned
    datasources = json.loads(
        monitor.succeed(
            "curl -sf -u admin:testpass http://localhost:${toString grafanaPort}/api/datasources"
        )
    )
    ds_names = [d["name"] for d in datasources]
    assert "Prometheus" in ds_names, f"Prometheus datasource missing, got: {ds_names}"
    assert "Loki" in ds_names, f"Loki datasource missing, got: {ds_names}"

    # Grafana can query Prometheus through its datasource proxy
    prom_query = json.loads(
        monitor.succeed(
            "curl -sf -u admin:testpass "
            "'http://localhost:${toString grafanaPort}/api/datasources/proxy/1/api/v1/query?query=up'"
        )
    )
    assert prom_query["status"] == "success", f"Grafana->Prometheus proxy query failed: {prom_query}"

    # --- Loki ---
    monitor.wait_for_unit("loki.service")
    monitor.wait_for_open_port(${toString lokiPort})
    monitor.wait_until_succeeds("curl -sf http://localhost:${toString lokiPort}/ready", 60)

    # --- Promtail ---
    target.wait_for_unit("promtail.service")

    # Generate some log traffic on target, wait for it to ship
    target.succeed("logger -t vm-test 'integration test log entry'")
    target.sleep(5)

    # Loki labels endpoint works (confirms log ingestion)
    monitor.wait_until_succeeds(
        "curl -sf http://localhost:${toString lokiPort}/loki/api/v1/labels | grep job",
        30,
    )
  '';
}
