# Comprehensive comparison of Keycloak admin user creation methods
# Each method can be tested by adjusting the `selectedMethod` variable

{ lib, pkgs, ... }:
let
  # Select which method to test (change this to test different methods)
  selectedMethod = "cli-bootstrap"; # Options: "initial-password", "kc-bootstrap-env", "keycloak-admin-env", "cli-bootstrap", "bootstrap-command"

  # Common database and basic settings
  baseKeycloakConfig = {
    enable = true;
    database = {
      type = "postgresql";
      createLocally = true;
      passwordFile = "/var/lib/keycloak/db-password";
    };
    settings = {
      hostname = "auth.robitzs.ch";
      http-enabled = true;
      http-port = 8080;
      proxy-headers = "xforwarded";
    };
  };
in
{
  # Apply base configuration plus method-specific options
  services.keycloak =
    baseKeycloakConfig
    // (
      if selectedMethod == "initial-password" then
        {
          # Method 1: NixOS initialAdminPassword option
          initialAdminPassword = "admin-adeci";
        }
      else
        { }
    );

  services.postgresql.enable = true;

  # Systemd service configuration varies by method
  systemd.services.keycloak = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    # Environment variables for different methods
    environment =
      if selectedMethod == "kc-bootstrap-env" then
        {
          # Method 2: KC_BOOTSTRAP_* environment variables (Keycloak 26+)
          KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
          KC_BOOTSTRAP_ADMIN_PASSWORD = "admin-adeci";
        }
      else if selectedMethod == "keycloak-admin-env" then
        {
          # Method 3: KEYCLOAK_ADMIN environment variables (legacy)
          KEYCLOAK_ADMIN = "admin";
          KEYCLOAK_ADMIN_PASSWORD = "admin-adeci";
        }
      else
        { };

    # Command line method overrides
    serviceConfig = lib.mkIf (selectedMethod == "cli-bootstrap") {
      # Method 4: Command line bootstrap parameters
      ExecStart = lib.mkForce [
        "" # Clear existing ExecStart
        "${pkgs.keycloak}/bin/kc.sh start --bootstrap-admin-username=admin --bootstrap-admin-password=admin-adeci --optimized"
      ];
    };

    # Database readiness check
    preStart = ''
      while ! ${pkgs.postgresql}/bin/pg_isready -h localhost; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
      done

      echo "=== Keycloak Admin Creation Method Test ==="
      echo "Selected method: ${selectedMethod}"
      echo "Admin username: admin"
      echo "Admin password: admin-adeci"
      echo "Test URL: https://auth.robitzs.ch/admin/"
      echo "=========================================="
    '';
  };

  # Method 5: Bootstrap command (requires separate service)
  systemd.services.keycloak-bootstrap = lib.mkIf (selectedMethod == "bootstrap-command") {
    description = "Bootstrap Keycloak admin user";
    wantedBy = [ "multi-user.target" ];
    before = [ "keycloak.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "keycloak";
      Group = "keycloak";
    };
    script = ''
      echo "Running bootstrap-admin user command..."
      ${pkgs.keycloak}/bin/kc.sh bootstrap-admin user --username admin --password:env BOOTSTRAP_PASS --no-prompt
    '';
    environment = {
      BOOTSTRAP_PASS = "admin-adeci";
    };
  };
}
