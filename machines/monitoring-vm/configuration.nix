{
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "24.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  networking = {
    hostName = "monitoring-vm";
    interfaces.eth0.useDHCP = lib.mkDefault true;
    firewall.allowedTCPPorts = [
      22 # SSH
      3000 # Grafana
      9090 # Prometheus
      3100 # Loki
      9093 # Alertmanager
    ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = lib.mkForce true;
    };
  };

  users.users.root.initialPassword = "monitor";
  services.getty.autologinUser = "root";

  systemd.services.demo-oem-credentials = {
    description = "Demo service showing OEM string credentials for monitoring services";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      LoadCredential = [
        "environment:ENVIRONMENT"
        "role:ROLE"
        "cluster:CLUSTER"
        "grafana-admin-password:HOST-GRAFANA-ADMIN-PASSWORD"
        "prometheus-token:HOST-PROMETHEUS-TOKEN"
        "loki-auth-token:HOST-LOKI-AUTH-TOKEN"
        "webhook-secret:HOST-WEBHOOK-SECRET"
        "monitoring-api-key:HOST-MONITORING-API-KEY"
      ];
    };

    script = ''
      echo "╔═══════════════════════════════════════════════════════════════╗"
      echo "║  OEM String Credentials (monitoring-vm)                      ║"
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""
      echo "✓ systemd credentials available:"
      ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "GRAFANA|PROMETHEUS|LOKI|WEBHOOK|MONITORING|ENVIRONMENT|ROLE|CLUSTER" || echo "  (none found)"
      echo ""
      echo "Static Configuration:"
      echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment 2>/dev/null || echo 'N/A')"
      echo "  ROLE        = $(cat $CREDENTIALS_DIRECTORY/role 2>/dev/null || echo 'N/A')"
      echo "  CLUSTER     = $(cat $CREDENTIALS_DIRECTORY/cluster 2>/dev/null || echo 'N/A')"
      echo ""
      echo "Monitoring Secrets (length check):"
      echo "  GRAFANA_ADMIN_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/grafana-admin-password 2>/dev/null || echo '0') bytes"
      echo "  PROMETHEUS_TOKEN       = $(wc -c < $CREDENTIALS_DIRECTORY/prometheus-token 2>/dev/null || echo '0') bytes"
      echo "  LOKI_AUTH_TOKEN       = $(wc -c < $CREDENTIALS_DIRECTORY/loki-auth-token 2>/dev/null || echo '0') bytes"
      echo "  WEBHOOK_SECRET        = $(wc -c < $CREDENTIALS_DIRECTORY/webhook-secret 2>/dev/null || echo '0') bytes"
      echo "  MONITORING_API_KEY    = $(wc -c < $CREDENTIALS_DIRECTORY/monitoring-api-key 2>/dev/null || echo '0') bytes"
      echo ""
      if [ $(wc -c < $CREDENTIALS_DIRECTORY/grafana-admin-password 2>/dev/null || echo '0') -gt 10 ]; then
        echo "✓ Monitoring secrets successfully loaded from HOST clan vars via OEM strings!"
      else
        echo "⚠️  Monitoring secrets not loaded"
      fi
      echo ""
      echo "✓ OEM string credentials successfully loaded via SMBIOS Type 11"
      echo "══════════════════════════════════════════════════════════════════"
    '';
  };

  # Monitoring stack packages (placeholders for now)
  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    jq
  ];

  # TODO: Add actual monitoring services (Prometheus, Grafana, Loki, etc.)
  # services.prometheus = { ... };
  # services.grafana = { ... };
  # services.loki = { ... };
}
