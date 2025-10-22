# Generic OpenTofu service management utilities
# Provides high-level service integration patterns for clan services
{
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    types
    mkOption
    optionalAttrs
    optionals
    ;

  # Import backend and terranix modules
  backendModule = import ./backends.nix { inherit lib pkgs config; };
  terranixModule = import ./terranix.nix { inherit lib pkgs; };

  # Service configuration options
  serviceOptions = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable OpenTofu integration for this service";
    };

    serviceName = mkOption {
      type = types.str;
      description = "Name of the clan service";
      example = "keycloak";
    };

    instanceName = mkOption {
      type = types.str;
      description = "Instance name for this service deployment";
      example = "main";
    };

    backend = mkOption {
      type = backendModule.types.backendConfig;
      default = {
        type = "local";
      };
      description = "OpenTofu backend configuration";
    };

    terranix = mkOption {
      type = terranixModule.types.terranixConfig;
      default = { };
      description = "Terranix configuration for terraform resources";
    };

    autoApply = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically apply terraform changes during deployment";
    };

    credentialFiles = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "Credential variable name";
            };
            source = mkOption {
              type = types.str;
              description = "Path to credential file";
            };
          };
        }
      );
      default = [ ];
      description = "Credential files to load into terraform variables";
    };

    dependsOn = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of systemd services this terraform deployment depends on";
      example = [
        "postgresql.service"
        "redis.service"
      ];
    };

    waitForService = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Service to wait for before applying terraform";
      example = "keycloak.service";
    };

    customWaitScript = mkOption {
      type = types.str;
      default = "";
      description = "Custom script to wait for service readiness";
      example = ''
        # Wait for HTTP 200 response
        for i in {1..60}; do
          if curl -s http://localhost:8080/health; then break; fi
          sleep 2
        done
      '';
    };

    variables = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.bool
          types.int
          types.float
        ]
      );
      default = { };
      description = "Terraform variables";
    };

    providers = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Terraform provider configurations";
    };

    lockTimeout = mkOption {
      type = types.int;
      default = 300;
      description = "Terraform state lock timeout in seconds";
    };

    enableHelperCommands = mkOption {
      type = types.bool;
      default = true;
      description = "Enable helper command scripts for terraform management";
    };
  };

  # Generate complete OpenTofu service integration
  generateOpenTofuService =
    serviceConfig:
    let
      inherit (serviceConfig)
        serviceName
        instanceName
        backend
        terranix
        autoApply
        ;
      inherit (serviceConfig)
        credentialFiles
        dependsOn
        waitForService
        customWaitScript
        ;
      inherit (serviceConfig) variables providers enableHelperCommands;

      # Generate terranix system
      terranixSystem = terranixModule.generateTerranixSystem {
        inherit
          serviceName
          instanceName
          variables
          providers
          credentialFiles
          ;
        config = terranix;
        buildTimeGeneration = true;
        changeDetection = autoApply;
      };

      # Generate backend system
      backendSystem = backendModule.generateOpenTofuBackend {
        inherit
          serviceName
          instanceName
          backend
          autoApply
          credentialFiles
          ;
        terraformConfig = terranixSystem.configFile;
        additionalDeps = dependsOn;
        inherit waitForService;
        waitScript = customWaitScript;
        terraformVars = variables;
        terraformVarsScript = terranixSystem.varsScript;
      };

      # Service name for terraform operations
      terraformServiceName = "${serviceName}-terraform-${instanceName}";
      deployServiceName = "${serviceName}-terraform-deploy-${instanceName}";

    in
    {
      # Systemd services
      systemd.services =
        backendSystem.services
        // optionalAttrs autoApply {
          ${deployServiceName} = backendSystem.deployService;
        };

      # Activation scripts
      system.activationScripts = optionalAttrs autoApply {
        "${serviceName}-terraform-reset-${instanceName}" = backendSystem.activationScript;
      };

      # Helper commands
      environment.systemPackages = optionals enableHelperCommands backendSystem.helperCommands;

      # Configuration validation
      assertions = [
        {
          assertion = terranixSystem.validateConfig.hasConfig;
          message = "OpenTofu service ${serviceName}-${instanceName} requires either terranix config or configPath";
        }
        {
          assertion = backend.type != "garage" || (backend.garageCredentials.adminTokenFile != null);
          message = "Garage backend requires adminTokenFile configuration";
        }
        {
          assertion =
            backend.type != "s3"
            || (backend.s3Credentials.accessKeyFile != null && backend.s3Credentials.secretKeyFile != null);
          message = "S3 backend requires both accessKeyFile and secretKeyFile configuration";
        }
      ];

      # Generated files and metadata
      _opentofu = {
        inherit serviceName instanceName;
        backend = backend;
        terranixConfig = terranixSystem.configFile;
        serviceNames = {
          terraform = terraformServiceName;
          deploy = deployServiceName;
        };
        generated = {
          configFile = terranixSystem.configFile;
          backendConfig = backendSystem.backendConfigGenerator;
          credentialLoader = backendSystem.credentialLoader;
        };
      };
    };

  # Convenience functions for common patterns
  commonPatterns = {
    # Keycloak service pattern
    keycloak =
      {
        instanceName,
        adminPasswordFile,
        backend ? {
          type = "local";
        },
      }:
      {
        serviceName = "keycloak";
        inherit instanceName backend;
        autoApply = true;
        dependsOn = [ "postgresql.service" ];
        waitForService = "keycloak.service";
        credentialFiles = [
          {
            name = "admin_password";
            source = adminPasswordFile;
          }
        ];
        variables = {
          keycloak_admin_password = "$CREDENTIALS_DIRECTORY/admin_password";
          keycloak_admin_new_password = "$CREDENTIALS_DIRECTORY/admin_password";
        };
        providers = {
          keycloak = {
            source = "registry.opentofu.org/mrparkers/keycloak";
            version = "~> 4.4";
            client_id = "admin-cli";
            username = "admin";
            password = "\${var.keycloak_admin_password}";
            url = "http://localhost:8080";
            realm = "master";
            initial_login = false;
            client_timeout = 60;
            tls_insecure_skip_verify = true;
          };
        };
      };

    # Database service pattern
    database =
      {
        instanceName,
        serviceName,
        backend ? {
          type = "local";
        },
      }:
      {
        inherit serviceName instanceName backend;
        autoApply = true;
        dependsOn = [ "postgresql.service" ];
        providers = {
          postgresql = {
            source = "registry.opentofu.org/cyrilgdn/postgresql";
            version = "~> 1.0";
          };
        };
      };

    # Generic HTTP service pattern
    httpService =
      {
        instanceName,
        serviceName,
        serviceUrl,
        backend ? {
          type = "local";
        },
      }:
      {
        inherit serviceName instanceName backend;
        autoApply = true;
        customWaitScript = ''
          # Wait for HTTP service to be ready
          echo "Waiting for ${serviceName} at ${serviceUrl}..."
          for i in {1..60}; do
            HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' ${serviceUrl} 2>/dev/null || echo "000")
            if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
              echo "${serviceName} is ready (HTTP $HTTP_CODE)"
              break
            fi
            [ $i -eq 60 ] && { echo "Timeout waiting for ${serviceName}"; exit 1; }
            echo "Waiting... (attempt $i/60, got HTTP $HTTP_CODE)"
            sleep 5
          done
        '';
      };
  };

  # Helper functions for backend configuration
  backendHelpers = {
    # Garage backend with clan vars integration
    garageWithClanVars =
      {
        bucket ? "terraform-state",
        keyPrefix ? "",
      }:
      {
        type = "garage";
        inherit bucket keyPrefix;
        endpoint = "http://127.0.0.1:3900";
        region = "garage";
        garageCredentials = {
          adminTokenFile =
            if config.clan.core.vars.generators ? "garage" then
              config.clan.core.vars.generators.garage.files.admin_token.path
            else
              null;
          rpcSecretFile =
            if config.clan.core.vars.generators ? "garage-shared" then
              config.clan.core.vars.generators.garage-shared.files.rpc_secret.path
            else
              null;
        };
      };

    # S3 backend with credential files
    s3WithCredentials =
      {
        bucket,
        endpoint ? null,
        region ? "us-east-1",
        accessKeyFile,
        secretKeyFile,
        keyPrefix ? "",
      }:
      {
        type = "s3";
        inherit
          bucket
          endpoint
          region
          keyPrefix
          ;
        s3Credentials = {
          inherit accessKeyFile secretKeyFile;
        };
      };

    # Local backend (default)
    local = {
      type = "local";
    };
  };

in
{
  # Main service generation function
  inherit generateOpenTofuService;

  # Common patterns
  patterns = commonPatterns;

  # Backend helpers
  backends = backendHelpers;

  # Option types
  options = {
    opentofu = serviceOptions;
  };

  # Re-export sub-modules
  inherit (backendModule) generateOpenTofuBackend;
  inherit (terranixModule) generateTerranixSystem helpers;

  # Types for external use
  types = {
    service = types.submodule { options = serviceOptions; };
    backend = backendModule.types.backendConfig;
    terranix = terranixModule.types.terranixConfig;
  };
}
