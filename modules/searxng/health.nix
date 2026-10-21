{
  lib,
  pkgs,
  config,
  settings,
  kagiEnvironmentFile,
}:
let
  healthPython = pkgs.python3.withPackages (_: [ config.services.searx.package ]);
  shutdownMarginSeconds = 5;
  monitored = settings.kagiHealthCheck && config.services.prometheus.enable;
in
{
  systemd = {
    services.searxng-kagi-health = lib.mkIf settings.kagiHealthCheck {
      description = "Check the private Kagi session without logging credentials";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      environment.SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        EnvironmentFile = kagiEnvironmentFile;
        ExecStart = "${healthPython}/bin/python -m searx.kagi_health --timeout-seconds ${toString settings.kagiTimeoutSeconds}";
        TimeoutStartSec = settings.kagiTimeoutSeconds + shutdownMarginSeconds;
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
        UMask = "0077";
      };
    };
    timers.searxng-kagi-health = lib.mkIf settings.kagiHealthCheck {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "5m";
      };
    };
  };
  services.prometheus = {
    scrapeConfigs =
      lib.mkIf
        (monitored && config.services.prometheus.exporters.blackbox.enable && settings.baseUrl != null)
        [
          {
            job_name = "searxng-health";
            metrics_path = "/probe";
            params.module = [ "http_2xx" ];
            static_configs = [ { targets = [ "${lib.removeSuffix "/" settings.baseUrl}/healthz" ]; } ];
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                source_labels = [ "__param_target" ];
                target_label = "instance";
              }
              {
                target_label = "__address__";
                replacement = "127.0.0.1:${toString config.services.prometheus.exporters.blackbox.port}";
              }
            ];
          }
        ];
    rules = lib.mkIf monitored [
      (builtins.toJSON {
        groups = [
          {
            name = "searxng";
            rules = [
              {
                alert = "SearxngUnavailable";
                expr = ''probe_success{job="searxng-health"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations.summary = "SearXNG HTTPS health endpoint failed on {{ $labels.instance }}";
              }
              {
                alert = "KagiSessionCheckFailed";
                expr = ''node_systemd_unit_state{name="searxng-kagi-health.service",state="failed"} == 1'';
                for = "5m";
                labels.severity = "warning";
                annotations.summary = "Kagi session check failed on {{ $labels.instance }}. Read the searxng-kagi-health journal for the non-secret failure category.";
              }
            ];
          }
        ];
      })
    ];
  };
}
