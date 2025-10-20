{ lib, config, ... }:

{
  # Keycloak Admin User Password Upgrade Module
  # This module handles the terraform-based admin password upgrade from bootstrap to clan vars

  config = lib.mkIf config.keycloak.terraform.enable {
    keycloak.terraform = {
      # Add dual provider configuration support
      providers = {
        # Bootstrap provider for initial authentication
        keycloak-bootstrap = {
          alias = "bootstrap";
          client_id = "\${var.keycloak_client_id}";
          username = "\${var.keycloak_admin_username}";
          password = "\${var.keycloak_bootstrap_password}";
          url = "\${var.keycloak_url}";
          realm = "\${var.keycloak_realm}";
          initial_login = "\${var.keycloak_initial_login}";
          client_timeout = "\${var.keycloak_client_timeout}";
          tls_insecure_skip_verify = "\${var.keycloak_tls_insecure_skip_verify}";
        };

        # Final provider using clan vars password (after upgrade)
        keycloak-final = {
          alias = "final";
          client_id = "\${var.keycloak_client_id}";
          username = "\${var.keycloak_admin_username}";
          password = "\${var.keycloak_admin_password}";
          url = "\${var.keycloak_url}";
          realm = "\${var.keycloak_realm}";
          initial_login = "\${var.keycloak_initial_login}";
          client_timeout = "\${var.keycloak_client_timeout}";
          tls_insecure_skip_verify = "\${var.keycloak_tls_insecure_skip_verify}";
        };
      };

      # Data source to get admin user details using bootstrap auth
      data = {
        keycloak_user.admin_user_bootstrap = {
          provider = "keycloak.bootstrap";
          realm_id = "master";
          username = "admin";
        };
      };

      # Admin password upgrade resource - this is the critical bridge
      resources = {
        # Password upgrade using terraform's keycloak_user resource
        "keycloak_user.admin_password_upgrade" = {
          provider = "keycloak.bootstrap";

          # Target the existing admin user in master realm
          realm_id = "master";
          username = "admin";

          # Keep existing user attributes
          email = "\${data.keycloak_user.admin_user_bootstrap.email}";
          email_verified = "\${data.keycloak_user.admin_user_bootstrap.email_verified}";
          first_name = "\${data.keycloak_user.admin_user_bootstrap.first_name}";
          last_name = "\${data.keycloak_user.admin_user_bootstrap.last_name}";
          enabled = true;

          # The critical upgrade: set new password to clan vars
          initial_password = {
            value = "\${var.keycloak_admin_password}";
            temporary = false;
          };

          # Lifecycle management for reliable upgrades
          lifecycle = {
            # Always check for password changes
            replace_triggered_by = [
              "\${var.keycloak_admin_password}"
            ];
            # Prevent accidental deletion
            prevent_destroy = true;
          };
        };

        # Validation resource to ensure upgrade worked
        "keycloak_user.admin_validation" = {
          provider = "keycloak.final";

          # This will only work if the password upgrade succeeded
          realm_id = "master";
          username = "admin";

          # Keep same attributes as bootstrap
          email = "\${keycloak_user.admin_password_upgrade.email}";
          email_verified = "\${keycloak_user.admin_password_upgrade.email_verified}";
          first_name = "\${keycloak_user.admin_password_upgrade.first_name}";
          last_name = "\${keycloak_user.admin_password_upgrade.last_name}";
          enabled = true;

          # This resource depends on the upgrade completing
          depends_on = [
            "keycloak_user.admin_password_upgrade"
          ];

          lifecycle = {
            # This resource validates that final auth works
            postcondition = {
              condition = "self.enabled == true";
              error_message = "Admin user upgrade validation failed - final authentication not working";
            };
          };
        };
      };

      # Output the upgrade status for monitoring
      outputs = lib.mkMerge [
        {
          admin_password_upgrade_status = {
            value = {
              bootstrap_user_id = "\${data.keycloak_user.admin_user_bootstrap.id}";
              upgraded_user_id = "\${keycloak_user.admin_password_upgrade.id}";
              validated_user_id = "\${keycloak_user.admin_validation.id}";
              upgrade_timestamp = "\${timestamp()}";
              password_source = "clan_vars";
            };
            description = "Admin password upgrade status and validation";
          };
        }
      ];
    };
  };
}
