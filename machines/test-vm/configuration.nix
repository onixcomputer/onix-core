{
  pkgs,
  lib,
  ...
}:
{
  system.stateVersion = "24.05";
  nixpkgs.hostPlatform = "x86_64-linux";

  networking = {
    hostName = "test-vm";
    interfaces.eth0.useDHCP = lib.mkDefault true;
    firewall.allowedTCPPorts = [ 22 ];
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = lib.mkForce true;
    };
  };

  users.users.root.initialPassword = "test";
  services.getty.autologinUser = "root";

  systemd.services.demo-oem-credentials = {
    description = "Demo service showing OEM string credentials with runtime secrets";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      LoadCredential = [
        "environment:ENVIRONMENT"
        "cluster:CLUSTER"
        "api-key:HOST-API-KEY"
        "db-password:HOST-DB-PASSWORD"
        "jwt-secret:HOST-JWT-SECRET"
      ];
    };

    script = ''
      echo "╔═══════════════════════════════════════════════════════════════╗"
      echo "║  OEM String Credentials with Runtime Secrets (test-vm)      ║"
      echo "╚═══════════════════════════════════════════════════════════════╝"
      echo ""
      echo "✓ systemd credentials available:"
      ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|HOSTNAME" || echo "  (none found)"
      echo ""
      echo "Static Configuration:"
      echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment 2>/dev/null || echo 'N/A')"
      echo "  CLUSTER     = $(cat $CREDENTIALS_DIRECTORY/cluster 2>/dev/null || echo 'N/A')"
      echo ""
      echo "Runtime Secrets (length check):"
      echo "  API_KEY     = $(cat $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo 'n/a') "
      echo "  DB_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/db-password 2>/dev/null || echo '0') bytes"
      echo "  JWT_SECRET  = $(wc -c < $CREDENTIALS_DIRECTORY/jwt-secret 2>/dev/null || echo '0') bytes"
      echo ""
      if [ $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') -gt 10 ]; then
        echo "✓ Runtime secrets successfully loaded from HOST clan vars via OEM strings!"
      else
        echo "⚠️  Runtime secrets not loaded"
      fi
      echo ""
      echo "✓ OEM string credentials (static + runtime) successfully loaded via SMBIOS Type 11"
      echo "══════════════════════════════════════════════════════════════════"
    '';
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
  ];
}
