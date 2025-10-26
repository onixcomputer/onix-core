# Pure OpenTofu Library Tests - For nix-unit testing
# Tests only pure functions that don't create derivations
{
  lib ? import <nixpkgs/lib>,
  # Import pure library functions - updated to use new modular structure
  opentofu ? (import ../../lib-pure.nix { inherit lib; }),
}:

{
  # Test credential mapping (fixed to handle sorted output)
  test_credential_mapping = {
    expr =
      let
        mapping = {
          "db_pass" = "db_password";
          "api_key" = "api_secret";
        };
        credentials = opentofu.generateLoadCredentials "test-service" mapping;
        # Sort credentials for deterministic testing
        sortedCredentials = builtins.sort (a: b: a < b) credentials;
      in
      {
        credentialCount = builtins.length credentials;
        firstCredential = builtins.head sortedCredentials;
        hasCorrectFormat = lib.hasInfix "/run/secrets/vars/test-service/" (builtins.head sortedCredentials);
      };
    expected = {
      credentialCount = 2;
      firstCredential = "api_key:/run/secrets/vars/test-service/api_secret";
      hasCorrectFormat = true;
    };
  };

  # Test tfvars generation
  test_tfvars_generation = {
    expr =
      let
        mapping = {
          "admin_password" = "admin_password";
        };
        script = opentofu.generateTfvarsScript mapping "";
      in
      {
        isString = builtins.isString script;
        hasPasswordVar = lib.hasInfix "admin_password" script;
        hasCredentialDir = lib.hasInfix "CREDENTIALS_DIRECTORY" script;
        hasTfvarsGeneration = lib.hasInfix "terraform.tfvars" script;
      };
    expected = {
      isString = true;
      hasPasswordVar = true;
      hasCredentialDir = true;
      hasTfvarsGeneration = true;
    };
  };

  # Test terranix validation
  test_terranix_validation = {
    expr =
      let
        validConfig = {
          terraform = {
            required_version = ">= 1.0";
            required_providers = {
              keycloak = {
                source = "mrparkers/keycloak";
                version = "~> 4.0";
              };
            };
          };
          provider.keycloak = {
            url = "http://localhost:8080";
          };
          resource.keycloak_realm.test = {
            realm = "test";
            enabled = true;
          };
        };
        isValid = opentofu.validateTerranixConfig validConfig;
      in
      {
        validationPassed = isValid == validConfig;
      };
    expected = {
      validationPassed = true;
    };
  };

  # Test service name generation
  test_service_name_generation = {
    expr =
      let
        serviceName = opentofu.makeServiceName "keycloak" "production";
        stateDir = opentofu.makeStateDirectory "keycloak" "production";
        lockFile = opentofu.makeLockFile "keycloak" "production";
      in
      {
        inherit serviceName stateDir lockFile;
        deploymentServiceName = opentofu.makeDeploymentServiceName "keycloak" "production";
      };
    expected = {
      serviceName = "keycloak-production";
      stateDir = "/var/lib/keycloak-production-terraform";
      lockFile = "/var/lib/keycloak-production-terraform/.terraform.lock";
      deploymentServiceName = "keycloak-terraform-deploy-production";
    };
  };

  # Test backend configuration generation
  test_backend_configs = {
    expr =
      let
        s3Config = opentofu.generateS3BackendConfig {
          serviceName = "test";
          instanceName = "prod";
        };
        localConfig = opentofu.generateLocalBackendConfig;
      in
      {
        s3HasEndpoint = lib.hasInfix "endpoint" s3Config;
        s3HasBucket = lib.hasInfix "terraform-state" s3Config;
        s3HasKey = lib.hasInfix "test/prod/terraform.tfstate" s3Config;
        localHasPath = lib.hasInfix "terraform.tfstate" localConfig;
      };
    expected = {
      s3HasEndpoint = true;
      s3HasBucket = true;
      s3HasKey = true;
      localHasPath = true;
    };
  };

  # Test script name generation
  test_script_names = {
    expr =
      let
        serviceName = "myservice";
        instanceName = "test";
      in
      {
        unlockScript = opentofu.makeUnlockScriptName serviceName instanceName;
        statusScript = opentofu.makeStatusScriptName serviceName instanceName;
        applyScript = opentofu.makeApplyScriptName serviceName instanceName;
        logsScript = opentofu.makeLogsScriptName serviceName instanceName;
      };
    expected = {
      unlockScript = "myservice-tf-unlock-test";
      statusScript = "myservice-tf-status-test";
      applyScript = "myservice-tf-apply-test";
      logsScript = "myservice-tf-logs-test";
    };
  };

  # Test configuration utilities
  test_config_utilities = {
    expr =
      let
        config1 = {
          a = 1;
          b = {
            c = 2;
          };
        };
        config2 = {
          b = {
            d = 3;
          };
          e = 4;
        };
        merged = opentofu.mergeConfigurations [
          config1
          config2
        ];

        terraformConfig = {
          variable = {
            admin_password = {
              type = "string";
            };
            db_host = {
              type = "string";
            };
          };
          resource = {
            keycloak_realm = {
              test = {
                realm = "test";
              };
              prod = {
                realm = "prod";
              };
            };
            keycloak_user = {
              admin = {
                username = "admin";
              };
            };
          };
        };

        variables = opentofu.extractVariables terraformConfig;
        resources = opentofu.extractResources terraformConfig;
      in
      {
        mergedA = merged.a;
        mergedBC = merged.b.c;
        mergedBD = merged.b.d;
        mergedE = merged.e;
        variableCount = builtins.length variables;
        resourceCount = builtins.length resources;
        hasAdminPassword = builtins.elem "admin_password" variables;
        hasKeycloakRealm = builtins.any (r: r.type == "keycloak_realm") resources;
      };
    expected = {
      mergedA = 1;
      mergedBC = 2;
      mergedBD = 3;
      mergedE = 4;
      variableCount = 2;
      resourceCount = 3;
      hasAdminPassword = true;
      hasKeycloakRealm = true;
    };
  };

  # Test service component extraction
  test_service_components = {
    expr =
      let
        components = opentofu.extractServiceComponents "keycloak" "prod";
      in
      {
        hasStateDir = components ? stateDir;
        hasLockFile = components ? lockFile;
        hasDeploymentService = components ? deploymentServiceName;
        hasScriptNames = components ? scriptNames;
        unlockScriptName = components.scriptNames.unlock;
        stateDirPath = components.stateDir;
      };
    expected = {
      hasStateDir = true;
      hasLockFile = true;
      hasDeploymentService = true;
      hasScriptNames = true;
      unlockScriptName = "keycloak-tf-unlock-prod";
      stateDirPath = "/var/lib/keycloak-prod-terraform";
    };
  };

  # Test credential mapping validation (updated for enhanced validation)
  test_credential_validation = {
    expr =
      let
        validMapping = {
          "user" = "username";
          "pass" = "password";
        };
        validated = opentofu.validateCredentialMapping validMapping;

        # Test that invalid mappings throw errors (null, not empty attrset)
        nullTest = builtins.tryEval (opentofu.validateCredentialMapping null);

      in
      {
        validationWorks = validated == validMapping;
        nullFails = !nullTest.success;
      };
    expected = {
      validationWorks = true;
      nullFails = true; # null should fail, but empty {} should pass
    };
  };

  # Test configuration ID generation
  test_config_id = {
    expr =
      let
        config1 = {
          a = 1;
          b = "test";
        };
        config2 = {
          a = 1;
          b = "test";
        };
        config3 = {
          a = 2;
          b = "test";
        };

        id1 = opentofu.generateConfigId config1;
        id2 = opentofu.generateConfigId config2;
        id3 = opentofu.generateConfigId config3;
      in
      {
        sameConfigsSameId = id1 == id2;
        differentConfigsDifferentId = id1 != id3;
        idIsString = builtins.isString id1;
        idNotEmpty = builtins.stringLength id1 > 0;
      };
    expected = {
      sameConfigsSameId = true;
      differentConfigsDifferentId = true;
      idIsString = true;
      idNotEmpty = true;
    };
  };

  # Test multiple credential mappings
  test_multiple_credentials = {
    expr =
      let
        mapping = {
          "database_password" = "db_pass";
          "api_token" = "api_secret";
          "admin_key" = "admin_secret";
        };
        credentials = opentofu.generateLoadCredentials "myapp" mapping;
        sortedCredentials = builtins.sort (a: b: a < b) credentials;
      in
      {
        credentialCount = builtins.length credentials;
        allHaveCorrectService = builtins.all (
          cred: lib.hasInfix "/run/secrets/vars/myapp/" cred
        ) credentials;
        firstCredential = builtins.head sortedCredentials;
        lastCredential = lib.last sortedCredentials;
      };
    expected = {
      credentialCount = 3;
      allHaveCorrectService = true;
      firstCredential = "admin_key:/run/secrets/vars/myapp/admin_secret";
      lastCredential = "database_password:/run/secrets/vars/myapp/db_pass";
    };
  };
}
