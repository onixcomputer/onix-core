# Clan instances monitoring and systemd-monitoring
# (inventory/services/services.ncl:628-697).
#
# The probe URLs are the values services.ncl derives from its RustFS, Celld,
# site Celld and niks3 address and port bindings (services.ncl:173-180, 245,
# 276, 327-331). The alert rules come from the file Clan reads.
{
  monitoring = {
    service = "prometheus",
    roles = {
      server = {
        tags = ["monitoring"],
        settings = {
          enable_auto_discovery = true,
          discovery_method = 'tailscale,
          port = 9090,
          global_config = {
            scrape_interval = "15s",
            evaluation_interval = "15s",
          },
          retention_time = "30d",
          additional_scrape_configs = [
            {
              job_name = "prometheus",
              static_configs = [{ targets = ["localhost:9090"] }],
            },
          ],
          http_probe_targets = [
            "http://100.100.103.95:39000/health",
            "http://100.108.13.4:39000/health",
            "http://100.110.43.11:39000/health",
            "http://100.100.103.95:39200/__celld/health",
            "http://100.108.13.4:39200/__celld/health",
            "http://100.110.43.11:39200/__celld/health",
            "http://100.108.13.4:32110/__celld/health",
            "http://100.110.43.11:32110/__celld/health",
            "http://100.100.103.95:39400/nix-cache-info",
          ],
          rules = import "../../inventory/services/prometheus-rules.ncl",
        },
      },
      exporter = {
        tags = ["prometheus"],
        settings = {
          exporter_type = 'node,
          port = 9100,
          enabled_collectors = [
            "systemd",
            "textfile",
            "processes",
            "mountstats",
            "meminfo",
            "loadavg",
            "filesystem",
            "cpu",
            "hwmon",
            "cpufreq",
            "powersupplyclass",
            "rapl",
          ],
        },
      },
    },
  },

  systemd-monitoring = {
    service = "prometheus",
    roles.exporter = {
      tags = ["prometheus"],
      settings = {
        exporter_type = 'systemd,
        port = 9558,
      },
    },
  },
}
