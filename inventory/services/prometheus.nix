_: {
  instances = {
    # Prometheus monitoring setup
    "monitoring" = {
      module.name = "prometheus";
      module.input = "self";

      # Prometheus server on machines with 'monitoring' tag
      roles.server = {
        tags."monitoring" = { };
        settings = {
          # Enable auto-discovery of exporters in the clan
          enableAutoDiscovery = true;

          # Use Tailscale for discovery
          discoveryMethod = "tailscale";

          # Alternative discovery methods:
          # discoveryMethod = "dns";
          # dnsDiscovery = {
          #   node = { names = [ "*.monitoring.local" ]; type = "A"; port = 9100; };
          #   systemd = { names = [ "*.monitoring.local" ]; type = "A"; port = 9558; };
          # };

          # discoveryMethod = "static";
          # staticTargets = {
          #   node = [ "192.168.1.10:9100" "192.168.1.11:9100" ];
          #   systemd = [ "192.168.1.10:9558" "192.168.1.11:9558" ];
          # };

          # Basic Prometheus configuration using freeform
          port = 9090;

          # Global configuration
          globalConfig = {
            scrape_interval = "15s";
            evaluation_interval = "15s";
          };

          # Data retention
          retentionTime = "30d";

          # Additional scrape configs beyond auto-discovery
          additionalScrapeConfigs = [
            {
              job_name = "prometheus";
              static_configs = [
                {
                  targets = [ "localhost:9090" ];
                }
              ];
            }
          ];

          # Alert rules
          rules = [
            ''
              groups:
                - name: system_alerts
                  interval: 30s
                  rules:
                    # CPU Alerts
                    - alert: HighCPUUsage
                      expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High CPU usage on {{ $labels.instance }}"
                        description: "CPU usage is above 80% (current value: {{ $value }}%)"
                    
                    - alert: HighLoadAverage
                      expr: node_load1 / count by (instance) (node_cpu_seconds_total{mode="system"}) > 2
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High load average on {{ $labels.instance }}"
                        description: "Load average is {{ $value }} per CPU"
                    
                    # Memory Alerts
                    - alert: LowMemory
                      expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.1
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Low memory available on {{ $labels.instance }}"
                        description: "Less than 10% memory available ({{ $value | humanizePercentage }})"
                    
                    - alert: HighMemoryUsage
                      expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
                      for: 10m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Critical memory usage on {{ $labels.instance }}"
                        description: "Memory usage is above 90% (current value: {{ $value }}%)"
                    
                    # Disk Alerts
                    - alert: LowDiskSpace
                      expr: node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|overlay"} / node_filesystem_size_bytes < 0.1
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Low disk space on {{ $labels.instance }}"
                        description: "Less than 10% disk space available on {{ $labels.mountpoint }} ({{ $value | humanizePercentage }})"
                    
                    - alert: DiskWillFillIn24Hours
                      expr: predict_linear(node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs|overlay"}[6h], 24*3600) < 0
                      for: 1h
                      labels:
                        severity: warning
                      annotations:
                        summary: "Disk will fill in 24 hours on {{ $labels.instance }}"
                        description: "Filesystem {{ $labels.mountpoint }} will fill up within 24 hours at current write rate"
                    
                    - alert: HighDiskIO
                      expr: rate(node_disk_io_time_seconds_total[5m]) > 0.9
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High disk I/O on {{ $labels.instance }}"
                        description: "Disk {{ $labels.device }} I/O utilization is above 90%"
                    
                    # Network Alerts
                    - alert: NetworkInterfaceDown
                      expr: node_network_up{device!~"lo|docker.*|veth.*"} == 0
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Network interface down on {{ $labels.instance }}"
                        description: "Network interface {{ $labels.device }} is down"
                    
                    - alert: HighNetworkTraffic
                      expr: (rate(node_network_receive_bytes_total[5m]) + rate(node_network_transmit_bytes_total[5m])) / 1024 / 1024 > 100
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High network traffic on {{ $labels.instance }}"
                        description: "Network traffic on {{ $labels.device }} is above 100 MB/s (current: {{ $value | humanize }}MB/s)"
                    
                    # NixOS/Systemd Alerts
                    - alert: SystemdServiceFailed
                      expr: node_systemd_unit_state{state="failed"} == 1
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Systemd service failed on {{ $labels.instance }}"
                        description: "Service {{ $labels.name }} is in failed state"
                    
                    - alert: SystemNotHealthy
                      expr: node_systemd_system_running == 0
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "System not healthy on {{ $labels.instance }}"
                        description: "Systemd reports system is not in 'running' state"
                    
                    - alert: HighSystemdRestarts
                      expr: changes(node_systemd_unit_start_time_seconds[1h]) > 5
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Service restarting frequently on {{ $labels.instance }}"
                        description: "Service {{ $labels.name }} has restarted {{ $value }} times in the last hour"
                    
                    # General System Alerts
                    - alert: InstanceDown
                      expr: up == 0
                      for: 5m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Instance {{ $labels.instance }} is down"
                        description: "Failed to scrape metrics from {{ $labels.instance }}"
                    
                    - alert: RebootRequired
                      expr: node_reboot_required > 0
                      for: 24h
                      labels:
                        severity: info
                      annotations:
                        summary: "Reboot required on {{ $labels.instance }}"
                        description: "System requires a reboot (kernel updates or similar)"
                    
                    - alert: ClockSkew
                      expr: abs(node_timex_offset_seconds) > 0.05
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Clock skew detected on {{ $labels.instance }}"
                        description: "Clock offset is {{ $value }} seconds"
                    
                    - alert: FileDescriptorsExhausted
                      expr: node_filefd_allocated / node_filefd_maximum > 0.9
                      for: 10m
                      labels:
                        severity: warning
                      annotations:
                        summary: "File descriptors exhausted on {{ $labels.instance }}"
                        description: "File descriptor usage is above 90% ({{ $value | humanizePercentage }})"
                    
                    # Power and Thermal Alerts
                    - alert: HighTemperature
                      expr: node_hwmon_temp_celsius > 80
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "High temperature on {{ $labels.instance }}"
                        description: "Temperature sensor {{ $labels.sensor }}/{{ $labels.chip }} is {{ $value }}°C"
                    
                    - alert: CriticalTemperature
                      expr: node_hwmon_temp_celsius > 95
                      for: 1m
                      labels:
                        severity: critical
                      annotations:
                        summary: "Critical temperature on {{ $labels.instance }}"
                        description: "Temperature sensor {{ $labels.sensor }}/{{ $labels.chip }} is {{ $value }}°C"
                    
                    - alert: HighPowerConsumption
                      expr: node_rapl_package_joules_total > 100
                      for: 10m
                      labels:
                        severity: info
                      annotations:
                        summary: "High power consumption on {{ $labels.instance }}"
                        description: "CPU package {{ $labels.index }} consuming high power"
                    
                    - alert: BatteryLow
                      expr: node_power_supply_capacity < 20 and node_power_supply_online == 0
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "Low battery on {{ $labels.instance }}"
                        description: "Battery level is {{ $value }}% and not charging"
                    
                    - alert: ThermalThrottling
                      expr: rate(node_cpu_frequency_hertz[5m]) < 0
                      for: 5m
                      labels:
                        severity: warning
                      annotations:
                        summary: "CPU thermal throttling on {{ $labels.instance }}"
                        description: "CPU {{ $labels.cpu }} frequency is decreasing, indicating thermal throttling"
            ''
          ];
        };
      };

      # Node exporters on all machines with 'prometheus' tag
      roles.exporter = {
        tags."prometheus" = { };
        settings = {
          exporterType = "node";
          port = 9100;

          # Node exporter specific settings
          enabledCollectors = [
            "systemd"
            "processes"
            "mountstats"
            "meminfo"
            "loadavg"
            "filesystem"
            "cpu"
            "hwmon" # Hardware monitoring sensors (temperature, voltage, fans, power)
            "cpufreq" # CPU frequency scaling
            "powersupplyclass" # Power supply information (battery, AC)
            "rapl" # Intel RAPL energy consumption (if available)
          ];
        };
      };
    };

    # Optional: systemd exporter for detailed service monitoring
    "systemd-monitoring" = {
      module.name = "prometheus";
      module.input = "self";

      roles.exporter = {
        tags."prometheus" = { };
        settings = {
          exporterType = "systemd";
          port = 9558;
        };
      };
    };
  };
}
