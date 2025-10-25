# OpenTofu Library Quick Start Guide
#
# This example demonstrates the layered architecture and common usage patterns
# for the OpenTofu library. Choose the level of abstraction that fits your needs.
{ lib, pkgs }:

let
  # Import the OpenTofu library
  opentofu = import ../default.nix { inherit lib pkgs; };

  # Example terranix module - creates a simple PostgreSQL configuration
  postgresModule =
    { settings }:
    {
      terraform = {
        required_providers = {
          postgresql = {
            source = "cyrilgdn/postgresql";
            version = "~> 1.0";
          };
        };
        required_version = ">= 1.0";
      };

      variable = {
        db_host = {
          description = "PostgreSQL host";
          type = "string";
          default = settings.host or "localhost";
        };
        admin_password = {
          description = "Admin password";
          type = "string";
          sensitive = true;
        };
      };

      provider = {
        postgresql = {
          host = "\${var.db_host}";
          port = 5432;
          username = "postgres";
          password = "\${var.admin_password}";
          sslmode = "require";
          connect_timeout = 15;
        };
      };

      resource = {
        postgresql_database.app_db = {
          name = settings.database or "myapp";
          owner = "postgres";
        };

        postgresql_role.app_user = {
          name = settings.username or "app_user";
          password = "\${var.admin_password}";
          login = true;
          create_database = false;
          create_role = false;
        };

        postgresql_grant.app_user_db = {
          database = "\${postgresql_database.app_db.name}";
          role = "\${postgresql_role.app_user.name}";
          privileges = [
            "CONNECT"
            "CREATE"
            "USAGE"
          ];
        };
      };

      output = {
        database_name = {
          description = "Created database name";
          value = "\${postgresql_database.app_db.name}";
        };
        connection_string = {
          description = "Database connection string";
          value = "postgresql://\${postgresql_role.app_user.name}@\${var.db_host}:5432/\${postgresql_database.app_db.name}";
          sensitive = true;
        };
      };
    };

in
{
  # ===============================================
  # LAYER 3: HIGH-LEVEL COMPOSITE FUNCTIONS
  # ===============================================
  # 🎯 RECOMMENDED FOR MOST USERS
  # These create complete NixOS configurations with all components

  # Complete PostgreSQL service with all components
  # Creates: systemd services + activation scripts + helper scripts + backend setup
  postgres_complete = opentofu.mkTerranixService {
    serviceName = "postgres";
    instanceName = "production";

    # Terranix configuration
    terranixModule = postgresModule;
    terranixModuleArgs = {
      settings = {
        host = "production-db.example.com";
        database = "myapp_prod";
        username = "myapp_user";
      };
    };

    # Credentials (will be loaded from clan vars)
    credentialMapping = {
      admin_password = "postgres_admin_password";
    };

    # Backend and dependencies
    backendType = "s3"; # Will auto-setup Garage if needed
    dependencies = [ "postgresql.service" ];

    # Optional features
    generateHelperScripts = true; # Creates postgres-tf-*-production scripts
    terranixValidate = true;
    cleanupOldConfigs = true;
    maxConfigHistory = 10;
  };

  # Quick deployment for development environments
  postgres_dev = opentofu.mkTerranixDeployment {
    serviceName = "postgres";
    instanceName = "dev";
    terranixModule = postgresModule;
    credentialMapping = {
      admin_password = "postgres_dev_password";
    };
    dependencies = [ "postgresql.service" ];
  };

  # ===============================================
  # LAYER 2: MODULAR FUNCTIONS
  # ===============================================
  # 🔧 FOR ADVANCED USERS WHO WANT CONTROL
  # These let you compose exactly what you need

  # Step 1: Generate terraform configuration
  postgres_config = opentofu.generateTerranixJson {
    module = postgresModule;
    moduleArgs = {
      settings = {
        host = "localhost";
        database = "myapp_dev";
        username = "dev_user";
      };
    };
    fileName = "postgres-terraform.json";
    validate = true;
    prettyPrintJson = true;
  };

  # Step 2: Create deployment service
  postgres_deployment = opentofu.mkTerranixInfrastructure {
    serviceName = "postgres";
    instanceName = "custom";
    terraformConfigPath = postgres_config;
    credentialMapping = {
      admin_password = "postgres_password";
    };
    backendType = "local";
    timeoutSec = "15m";
    preTerraformScript = ''
      echo "Setting up PostgreSQL terraform deployment..."
      # Custom pre-deployment logic here
    '';
  };

  # Step 3: Create activation script
  postgres_activation = opentofu.mkTerranixActivation {
    serviceName = "postgres";
    instanceName = "custom";
    terraformConfigPath = postgres_config;
  };

  # Step 4: Create helper scripts
  postgres_helpers = opentofu.mkTerranixScripts {
    serviceName = "postgres";
    instanceName = "custom";
  };

  # ===============================================
  # LAYER 1: PURE FUNCTIONS
  # ===============================================
  # ⚙️ FOR LIBRARY AUTHORS AND POWER USERS
  # These are the building blocks used by higher layers

  # Pure configuration utilities
  postgres_paths = {
    serviceName = opentofu.makeServiceName "postgres" "example";
    stateDir = opentofu.makeStateDirectory "postgres" "example";
    lockFile = opentofu.makeLockFile "postgres" "example";
    scriptNames = {
      unlock = opentofu.makeUnlockScriptName "postgres" "example";
      status = opentofu.makeStatusScriptName "postgres" "example";
      apply = opentofu.makeApplyScriptName "postgres" "example";
      logs = opentofu.makeLogsScriptName "postgres" "example";
    };
  };

  # Credential utilities
  postgres_credentials = opentofu.generateLoadCredentials "postgres-production" {
    admin_password = "postgres_admin_password";
    readonly_password = "postgres_readonly_password";
  };

  # Backend configuration
  postgres_backend = opentofu.generateS3BackendConfig {
    serviceName = "postgres";
    instanceName = "production";
  };

  # ===============================================
  # COMMON PATTERNS AND EXAMPLES
  # ===============================================

  # Multi-environment pattern
  environments = lib.genAttrs [ "dev" "staging" "prod" ] (
    env:
    opentofu.mkTerranixService {
      serviceName = "postgres";
      instanceName = env;
      terranixModule = postgresModule;
      terranixModuleArgs = {
        settings = {
          host = "${env}-db.example.com";
          database = "myapp_${env}";
          username = "myapp_${env}";
        };
      };
      credentialMapping = {
        admin_password = "postgres_${env}_password";
      };
      backendType = if env == "prod" then "s3" else "local";
      dependencies = [ "postgresql.service" ];
    }
  );

  # Migration from JSON to Terranix pattern
  legacy_json_service = opentofu.mkTerranixInfrastructure {
    serviceName = "legacy";
    instanceName = "main";
    terraformConfigPath = ./legacy-config.json; # Existing JSON config
    credentialMapping = {
      api_key = "legacy_api_key";
    };
  };

  # Testing and validation pattern
  postgres_tests = opentofu.testTerranixModule {
    module = postgresModule;
    testCases = {
      "minimal" = {
        settings = {
          host = "localhost";
        };
      };
      "production" = {
        settings = {
          host = "prod-db.example.com";
          database = "myapp_prod";
          username = "prod_user";
        };
      };
    };
    expectedBlocks = [
      "terraform"
      "provider"
      "resource"
      "output"
    ];
  };

  # ===============================================
  # USAGE RECOMMENDATIONS
  # ===============================================

  # 👍 Most users should use: mkTerranixService
  # - Handles everything: systemd services, activation, scripts, backends
  # - Sensible defaults with customization options
  # - One function call creates complete working service

  # 🔧 Advanced users can use: mkTerranixInfrastructure + mkTerranixActivation
  # - More control over individual components
  # - Custom composition of features
  # - Better for complex deployment workflows

  # ⚙️ Library authors can use: Pure functions + Modular functions
  # - Maximum flexibility and control
  # - Building custom higher-level abstractions
  # - Creating domain-specific deployment tools

  # 📚 Migration path: JSON → Terranix → mkTerranixService
  # 1. Start with existing JSON config using mkTerranixInfrastructure
  # 2. Convert to terranix module when ready
  # 3. Upgrade to mkTerranixService for full integration
}
