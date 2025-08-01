# Prometheus Clan Service

A clan service module for Prometheus monitoring with automatic service discovery.

## Overview

Prometheus is a pull-based monitoring system that collects time-series metrics from HTTP endpoints. This module provides:

- Automatic discovery of clan machines via Tailscale/DNS/static configs
- Role-based deployment (servers collect, exporters expose)
- Pass-through configuration to NixOS's prometheus module

## Architecture

**Two roles:**

- `server`: Runs Prometheus (scrapes metrics, stores data, evaluates alerts)
- `exporter`: Exposes metrics for collection (node stats, systemd status)

**Discovery flow:**

1. Prometheus servers discover machines based on configured method
1. Servers scrape metrics from discovered exporters (ports 9100, 9558)
1. Data stored locally on server for querying/alerting

## Configuration

### Freeform Options

The module uses `freeformType = attrsOf anything` to pass configuration directly to NixOS's `services.prometheus`. Any valid prometheus option works:

```nix
settings = {
  # Clan-specific options
  enableAutoDiscovery = true;
  discoveryMethod = "tailscale";

  # Standard prometheus options (passed through)
  port = 9090;
  retentionTime = "30d";
  globalConfig = {
    scrape_interval = "15s";
  };
}
```

### Discovery Methods

**Tailscale** (requires tailscale enabled):

```nix
discoveryMethod = "tailscale";
# Auto-discovers all machines on tailnet
```

**DNS**:

```nix
discoveryMethod = "dns";
dnsDiscovery = {
  node = {
    names = [ "*.monitoring.local" ];
    type = "A";
    port = 9100;
  };
};
```

**Static**:

```nix
discoveryMethod = "static";
staticTargets = {
  node = [ "10.0.0.5:9100" "10.0.0.6:9100" ];
  systemd = [ "10.0.0.5:9558" "10.0.0.6:9558" ];
};
```

## Example Inventory Configuration

```nix
{
  instances = {
    "monitoring" = {
      module.name = "prometheus";
      module.input = "self";

      # Deploy prometheus server on machines tagged 'monitoring-server'
      roles.server = {
        tags."monitoring-server" = {};
        settings = {
          enableAutoDiscovery = true;
          discoveryMethod = "tailscale";
          port = 9090;
          retentionTime = "30d";

          # Alert rules
          rules = [ ... ];

          # Additional manual targets
          additionalScrapeConfigs = [
            {
              job_name = "external-service";
              static_configs = [{
                targets = [ "api.example.com:9090" ];
              }];
            }
          ];
        };
      };

      # Deploy exporters on all machines
      roles.exporter = {
        tags."all" = {};
        settings = {
          exporterType = "node";
          port = 9100;
          enabledCollectors = [
            "systemd"
            "cpu"
            "memory"
            "disk"
            "network"
          ];
        };
      };
    };
  };
}
```

## Collected Metrics

**Node exporter** provides:

- CPU usage, load averages
- Memory/swap usage
- Disk space and I/O
- Network traffic
- Systemd service states

**Additional exporters** available:

- `systemd`: Detailed service metrics
- `nginx`: Web server stats
- `postgres`: Database metrics
- `redis`: Cache performance

## Security

- Exporters open firewall ports (9100, 9558) on all interfaces
- Within Tailscale: traffic encrypted, identity-based access
- No built-in authentication - relies on network security
- Consider restricting ports to tailscale0 interface only

## Usage

1. Tag machines for roles (e.g., `monitoring-server`, `all`)
1. Deploy configuration: `clan machines update <machine>`
1. Access Prometheus UI: `http://<server-ip>:9090`
1. Query metrics with PromQL or visualize with Grafana
