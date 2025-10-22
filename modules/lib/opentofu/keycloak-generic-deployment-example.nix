# Example: Keycloak module using the generic OpenTofu blocking deployment pattern
#
# This shows how to integrate the extracted deployment pattern with the keycloak module.
# It replaces the manual activation script and systemd service configuration with
# the reusable generic pattern.

{ lib, ... }:

{
  # This example shows the key parts of a keycloak module refactored to use
  # the generic deployment pattern from modules/lib/opentofu/deployment.nix

  # In the keycloak clan service module perInstance function:
  nixosModule =
    { config, pkgs, ... }:
    let
      instanceName = "production"; # This would come from perInstance parameters
      generatorName = "keycloak-${instanceName}";

      # Settings from clan service interface
      terraformBackend = "local"; # or "s3"
      terraformAutoApply = true;
      domain = "auth.example.com";

      # Generate Terraform configuration at build time
      terraformConfigJson = pkgs.writeText "keycloak-terraform-${instanceName}.json" (
        builtins.toJSON {
          # Simplified terraform config for demo
          terraform.required_providers.keycloak = {
            source = "mrparkers/keycloak";
            version = "~> 4.4";
          };
          provider.keycloak = {
            client_id = "admin-cli";
            username = "admin";
            password = "\${var.keycloak_admin_password}";
            url = "http://localhost:8080";
            realm = "master";
          };
          resource.keycloak_user.admin = {
            realm_id = "master";
            username = "admin";
            enabled = true;
            initial_password = {
              value = "\${var.keycloak_admin_new_password}";
              temporary = false;
            };
          };
        }
      );

      # Credential mapping for OpenTofu library
      credentialMapping = {
        "keycloak_admin_password" = "admin_password";
        "keycloak_admin_new_password" = "admin_password";
      };

      # Dependencies for terraform deployment
      deploymentDependencies = [
        "keycloak.service"
      ]
      ++ lib.optionals (terraformBackend == "s3") [ "garage-terraform-init-${instanceName}.service" ];

      # S3 configuration (for garage backend)
      s3Config = lib.mkIf (terraformBackend == "s3") {
        credentialsPath = "/var/lib/garage-terraform-${instanceName}";
      };

    in
    {
      imports = [
        # Import the OpenTofu library
        ../lib/opentofu
      ];

      # Configure OpenTofu credential mapping
      opentofu.credentialMapping = credentialMapping;

      # STANDARD KEYCLOAK CONFIGURATION (unchanged)
      services = {
        keycloak = {
          enable = true;
          initialAdminPassword = "TemporaryBootstrapPassword123!";
          settings = {
            hostname = domain;
            proxy-headers = "xforwarded";
            http-enabled = true;
            http-port = 8080;
          };
          database = {
            type = "postgresql";
            createLocally = true;
            passwordFile = config.clan.core.vars.generators.${generatorName}.files.db_password.path;
          };
        };

        postgresql.enable = true;

        nginx = {
          enable = true;
          recommendedTlsSettings = true;
          recommendedOptimisation = true;
          recommendedGzipSettings = true;
          recommendedProxySettings = true;

          virtualHosts."keycloak-${instanceName}" = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 9080;
              }
            ];
            locations."/" = {
              proxyPass = "http://localhost:8080";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto https;
                proxy_set_header X-Forwarded-Host ${domain};
                proxy_set_header Host ${domain};
              '';
            };
          };
        };
      };

      # CLAN VARS GENERATORS (unchanged)
      clan.core.vars.generators.${generatorName} = {
        files = {
          db_password = {
            deploy = true;
          };
          admin_password = {
            deploy = true;
          };
        };
        runtimeInputs = [ pkgs.pwgen ];
        script = ''
          ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/db_password
          ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/admin_password
        '';
      };

      # GARAGE BUCKET SETUP (if using S3 backend - unchanged)
      systemd.services."garage-terraform-init-${instanceName}" = lib.mkIf (terraformBackend == "s3") {
        description = "Initialize Garage bucket for Keycloak Terraform";
        after = [ "garage.service" ];
        requires = [ "garage.service" ];
        before = [ "keycloak-terraform-deploy-${instanceName}.service" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "garage-terraform-${instanceName}";
          WorkingDirectory = "/var/lib/garage-terraform-${instanceName}";
        };

        script = ''
          # Garage bucket and credential setup script (unchanged from original)
          echo "Setting up Garage bucket and credentials..."
          # ... existing garage setup logic ...
        '';
      };

    }
    // (
      # NEW: Apply the generic blocking deployment pattern
      config._lib.opentofu.deployment.mkBlockingDeployment {
        serviceName = "keycloak";
        inherit instanceName;
        terraformConfigPath = terraformConfigJson;
        inherit terraformBackend;
        blockingDeployment = true;
        enableDeployment = terraformAutoApply;
        dependencies = deploymentDependencies;
        timeoutStartSec = "10m";
        inherit s3Config;
        healthCheck = {
          enable = true;
          url = "http://localhost:8080/";
          expectedHttpCodes = [
            "200"
            "302"
          ];
          maxAttempts = 60;
          intervalSeconds = 2;
        };
        preTerraformScript = config._lib.opentofu.generateTfvarsScript credentialMapping "";
      }
    )
    // {
      # Merge the deployment pattern with additional credential loading
      systemd.services."keycloak-terraform-deploy-${instanceName}" = {
        serviceConfig = {
          LoadCredential = config._lib.opentofu.generateLoadCredentials generatorName credentialMapping;
        };
      };
    };
}

# BENEFITS OF THIS APPROACH:
#
# 1. REPLACES the entire activation script (15 lines) with the generic pattern
# 2. REPLACES the oneshot deployment service (160 lines) with the generic pattern
# 3. REPLACES manual credential loading (5 lines) with library function
# 4. REPLACES manual tfvars generation (8 lines) with library function
# 5. REPLACES manual health check logic (15 lines) with configurable pattern
# 6. REPLACES manual backend configuration (25 lines) with generic pattern
# 7. PROVIDES consistent helper commands (status, deploy, reset) automatically
# 8. PROVIDES reusable state management and change detection
# 9. PROVIDES configurable timeouts and retry logic
# 10. WORKS with any terraform backend (local, s3/garage, etc.)
#
# TOTAL: Replaces ~230 lines of service-specific code with ~15 lines of configuration
#
# The pattern is now reusable across all clan services that need terraform deployment!
