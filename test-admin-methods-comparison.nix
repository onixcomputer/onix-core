# Comprehensive test configuration for Keycloak admin user creation methods
# This file can be used to test different methods by uncommenting different sections

{ lib, pkgs, ... }:
let
  # Common settings for all test methods
  commonKeycloakConfig = {
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

  # Test method selection (uncomment one at a time)
  testMethod = "kc-bootstrap"; # Options: "initial-password", "kc-bootstrap", "keycloak-admin", "command-line"
in
{
  services.keycloak =
    commonKeycloakConfig
    // (
      if testMethod == "initial-password" then
        {
          # Method 1: initialAdminPassword (NixOS built-in)
          initialAdminPassword = "admin-adeci";
        }
      else
        { }
    );

  services.postgresql.enable = true;

  systemd.services.keycloak = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];

    # Environment variables based on test method
    environment =
      if testMethod == "kc-bootstrap" then
        {
          # Method 2: KC_BOOTSTRAP_* environment variables (Modern Keycloak 26+)
          KC_BOOTSTRAP_ADMIN_USERNAME = "admin";
          KC_BOOTSTRAP_ADMIN_PASSWORD = "admin-adeci";
        }
      else if testMethod == "keycloak-admin" then
        {
          # Method 3: KEYCLOAK_ADMIN environment variables (Legacy)
          KEYCLOAK_ADMIN = "admin";
          KEYCLOAK_ADMIN_PASSWORD = "admin-adeci";
        }
      else
        { };

    # Command line method override
    serviceConfig = lib.mkIf (testMethod == "command-line") {
      ExecStart = lib.mkForce "${pkgs.keycloak}/bin/kc.sh start --bootstrap-admin-username=admin --bootstrap-admin-password=admin-adeci --optimized";
    };

    preStart = ''
      while ! ${pkgs.postgresql}/bin/pg_isready -h localhost; do
        echo "Waiting for PostgreSQL to be ready..."
        sleep 2
      done

      echo "Testing admin creation method: ${testMethod}"
      echo "Admin username: admin"
      echo "Admin password: admin-adeci"
      echo "Expected login URL: https://auth.robitzs.ch/admin/"
    '';
  };
}
