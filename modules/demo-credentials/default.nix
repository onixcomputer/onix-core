{ lib, ... }:
let
  inherit (lib) mkOption mkDefault;
  inherit (lib.types) str attrsOf anything;
in
{
  _class = "clan.service";

  manifest = {
    name = "demo-credentials";
    description = "Demo service showing OEM string credentials with runtime secrets";
    categories = [
      "Development"
      "Demo"
      "Security"
    ];
  };

  roles = {
    server = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          environment = mkOption {
            type = str;
            default = "development";
            description = "Environment name for the demo credentials";
          };

          cluster = mkOption {
            type = str;
            default = "local";
            description = "Cluster name for the demo credentials";
          };

          serviceName = mkOption {
            type = str;
            default = "demo-oem-credentials";
            description = "Name of the systemd service";
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { pkgs, ... }:
            let
              cfg = extendSettings {
                environment = mkDefault "development";
                cluster = mkDefault "local";
                serviceName = mkDefault "demo-oem-credentials-${instanceName}";
              };

              serviceName = cfg.serviceName;
            in
            {
              # Clan vars generators for demo credentials
              clan.core.vars.generators."demo-credentials-${instanceName}" = {
                files = {
                  api-key = { };
                  db-password = { };
                  jwt-secret = { };
                  environment = { };
                  cluster = { };
                };
                runtimeInputs = with pkgs; [
                  coreutils
                  openssl
                ];
                script = ''
                  # Generate runtime secrets
                  openssl rand -base64 32 > "$out/api-key"
                  openssl rand -base64 24 > "$out/db-password"
                  openssl rand -base64 48 > "$out/jwt-secret"

                  # Static configuration values
                  echo "${cfg.environment}" > "$out/environment"
                  echo "${cfg.cluster}" > "$out/cluster"
                '';
              };

              # Demo credentials systemd service
              systemd.services.${serviceName} = {
                description = "Demo service showing OEM string credentials with runtime secrets (${instanceName})";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StandardOutput = "journal+console";
                  StandardError = "journal+console";
                  # Service works standalone for demo purposes
                };

                script = ''
                  echo "╔═══════════════════════════════════════════════════════════════╗"
                  echo "║  Demo Credentials Service (${instanceName})                   ║"
                  echo "╚═══════════════════════════════════════════════════════════════╝"
                  echo ""
                  echo "Environment Information:"
                  echo "  HOSTNAME    = $(hostname)"
                  echo "  ENVIRONMENT = ${cfg.environment}"
                  echo "  CLUSTER     = ${cfg.cluster}"
                  echo "  INSTANCE    = ${instanceName}"
                  echo ""
                  echo "✓ systemd credentials available:"
                  ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|HOSTNAME" || echo "  (none found)"
                  echo ""

                  # Generate demo credentials on-the-fly for demonstration
                  echo "Demo Runtime Secrets (generated):"
                  DEMO_API_KEY="$(${pkgs.openssl}/bin/openssl rand -base64 32)"
                  DEMO_DB_PASS="$(${pkgs.openssl}/bin/openssl rand -base64 16)"
                  DEMO_JWT="$(${pkgs.openssl}/bin/openssl rand -base64 48)"

                  echo "  API_KEY     = ''${#DEMO_API_KEY} bytes (''${DEMO_API_KEY:0:8}...)"
                  echo "  DB_PASSWORD = ''${#DEMO_DB_PASS} bytes"
                  echo "  JWT_SECRET  = ''${#DEMO_JWT} bytes"
                  echo ""

                  if [ -d "$CREDENTIALS_DIRECTORY" ]; then
                    echo "✓ systemd credentials directory available"
                    ls -la "$CREDENTIALS_DIRECTORY" 2>/dev/null || echo "  (empty)"
                  else
                    echo "ⓘ No external credentials - demo service running standalone"
                  fi
                  echo ""
                  echo "✓ Demo credentials service completed successfully"
                  echo "  Service demonstrates credential management in ${instanceName} environment"
                  echo "══════════════════════════════════════════════════════════════════"
                '';
              };
            };
        };
    };
  };
}
