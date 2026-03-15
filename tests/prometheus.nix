# VM test: Prometheus server scrapes node exporter and responds to queries.
{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  name = "prometheus";

  nodes.monitor = {
    virtualisation.graphics = false;

    services.prometheus = {
      enable = true;
      port = 9090;

      globalConfig = {
        scrape_interval = "2s";
        evaluation_interval = "2s";
      };

      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "localhost:9090" ]; }
          ];
        }
        {
          job_name = "node";
          static_configs = [
            { targets = [ "localhost:9100" ]; }
          ];
        }
      ];

      rules = [
        ''
          groups:
            - name: test_alerts
              rules:
                - alert: AlwaysFiring
                  expr: up == 1
                  labels:
                    severity: info
                  annotations:
                    summary: "Test alert"
        ''
      ];
    };

    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [
        "systemd"
        "cpu"
        "meminfo"
        "loadavg"
        "filesystem"
      ];
    };

    networking.firewall.allowedTCPPorts = [
      9090
      9100
    ];
  };

  testScript = ''
    monitor.wait_for_unit("prometheus.service")
    monitor.wait_for_unit("prometheus-node-exporter.service")
    monitor.wait_for_open_port(9090)
    monitor.wait_for_open_port(9100)

    # Prometheus is healthy
    monitor.succeed("curl -sf http://localhost:9090/-/healthy")

    # Node exporter returns metrics
    output = monitor.succeed("curl -sf http://localhost:9100/metrics")
    assert "node_cpu_seconds_total" in output, "Missing CPU metrics from node exporter"
    assert "node_memory_MemTotal_bytes" in output, "Missing memory metrics from node exporter"

    # Wait for scrape to complete, then query
    monitor.sleep(5)

    import json
    result = json.loads(
        monitor.succeed(
            "curl -sf 'http://localhost:9090/api/v1/query?query=up'"
        )
    )
    assert result["status"] == "success", f"Query failed: {result}"

    # Both targets should be up
    targets = json.loads(
        monitor.succeed("curl -sf http://localhost:9090/api/v1/targets")
    )
    active = targets["data"]["activeTargets"]
    assert len(active) >= 2, f"Expected at least 2 targets, got {len(active)}"

    # Alert rules loaded
    rules = json.loads(
        monitor.succeed("curl -sf http://localhost:9090/api/v1/rules")
    )
    groups = rules["data"]["groups"]
    assert any(g["name"] == "test_alerts" for g in groups), "Alert rule group not loaded"
  '';
}
