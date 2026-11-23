# One-shot AMD GPU metrics collector for the Prometheus node-exporter textfile collector.
# NixOS uses inventory/tags/amd-gpu.nix with this same collector body.
fun onix =>
  let collector_body = import "../../inventory/tags/amd-gpu-exporter.sh" as 'Text in
  ({
    interface = {
      manifest = {
        name = "onix-core/amd-gpu-exporter",
        description = "AMD GPU metrics for Prometheus node-exporter's textfile collector.",
        categories = ["monitoring", "metrics", "hardware"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS uses inventory/tags/amd-gpu.nix; this module emits the matching systemd-host unit and timer.",
          },
        ],
      },
      packages = ["bash", "coreutils", "jq", "rocm-smi=rocmPackages.rocm-smi"],
      roles.host = {},
    },

    impl = fun args =>
      let p = args.package_paths in
      let tool_path =
        [p."rocm-smi", p.jq, p.coreutils]
        |> std.array.map (fun package => "%{package}/bin")
        |> std.string.join ":"
      in
      let collector_header = m%"
        #!%{p.bash}/bin/bash
        set -euo pipefail
        export PATH=%{tool_path}
      "%
      in
      {
        output.host = {
          packages = [p.bash, p.coreutils, p.jq, p."rocm-smi"],
          groups."prometheus-amd-gpu" = {},
          users."prometheus-amd-gpu" = {
            group = "prometheus-amd-gpu",
            description = "AMD GPU Metrics Exporter User",
            extra_groups = ["render", "video", "node-exporter"],
          },
          files = {
            "amd-gpu-exporter/collect.sh" = {
              text = collector_header ++ "\n" ++ collector_body,
              mode = "0755",
            },
            "amd-gpu-exporter/check-device.sh" = {
              text = m%"
                #!%{p.bash}/bin/bash
                for path in /sys/class/drm/card[0-9]*/device/vendor; do
                  if [[ -r "$path" ]]; then
                    read -r vendor < "$path" || continue
                    if [[ $vendor == 0x1002 ]]; then exit 0; fi
                  fi
                done
                exit 1
              "%,
              mode = "0755",
            },
          },
          units = {
            "amd-gpu-exporter.service" = {
              sections = {
                Unit = {
                  Description = "AMD GPU Metrics Exporter for Prometheus",
                  ConditionPathExistsGlob = "/sys/class/drm/card[0-9]*/device/vendor",
                  After = ["network-online.target", "systemd-tmpfiles-setup.service"],
                  Wants = "network-online.target",
                },
                Service = {
                  Type = "oneshot",
                  ExecCondition = "%{p.bash}/bin/bash /etc/amd-gpu-exporter/check-device.sh",
                  ExecStart = "%{p.bash}/bin/bash /etc/amd-gpu-exporter/collect.sh",
                  User = "prometheus-amd-gpu",
                  Group = "prometheus-amd-gpu",
                  SupplementaryGroups = ["render", "video", "node-exporter"],
                  NoNewPrivileges = "true",
                  ProtectSystem = "strict",
                  ProtectHome = "true",
                  PrivateTmp = "true",
                  ReadWritePaths = "/var/lib/prometheus-node-exporter-text-files",
                },
              },
            },
            "amd-gpu-exporter.timer" = {
              sections = {
                Unit.Description = "Collect AMD GPU metrics every 5 seconds",
                Timer = {
                  OnBootSec = "5s",
                  OnUnitActiveSec = "5s",
                  AccuracySec = "1s",
                  Unit = "amd-gpu-exporter.service",
                },
              },
              wanted_by = ["timers.target"],
            },
          },
        },
      },
  }
  ) | onix.ServiceModule
