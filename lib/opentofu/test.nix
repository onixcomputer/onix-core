# Unit tests for OpenTofu library and terranix integration
# Following clan patterns from lib/introspection/test.nix
{
  lib ? import <nixpkgs/lib>,
  pkgs ? import <nixpkgs> { },
  # Import OpenTofu library from current directory like clan-core pattern
  opentofu ? (import ./. { inherit lib pkgs; }),
}:

let

  # Test settings - minimal keycloak configuration
  testSettings = {
    terraform = {
      realms = {
        test = {
          enabled = true;
          displayName = "Test Realm";
        };
      };
      users = {
        testuser = {
          realm = "test";
          username = "testuser";
          enabled = true;
          email = "test@example.com";
          firstName = "Test";
          lastName = "User";
        };
      };
    };
  };

in
{
  # Test basic terranix configuration generation
  test_basic_terranix_config = {
    expr =
      let
        config = import ../../keycloak/terranix-wrapper.nix {
          inherit lib;
          settings = testSettings;
        };
      in
      {
        hasProvider = config ? provider;
        hasResources = config ? resource;
        hasVariables = config ? variable;
        hasRealms = config.resource ? keycloak_realm;
        hasUsers = config.resource ? keycloak_user;
        realmCount = builtins.length (builtins.attrNames (config.resource.keycloak_realm or { }));
        userCount = builtins.length (builtins.attrNames (config.resource.keycloak_user or { }));
      };
    expected = {
      hasProvider = true;
      hasResources = true;
      hasVariables = true;
      hasRealms = true;
      hasUsers = true;
      realmCount = 1; # test realm
      userCount = 2; # admin + testuser
    };
  };

  # Test helper script generation
  test_helper_scripts = {
    expr =
      let
        scripts = opentofu.mkHelperScripts {
          serviceName = "test";
          instanceName = "unit";
        };
      in
      {
        scriptCount = builtins.length scripts;
        isFirstScriptValid = builtins.isDerivation (builtins.head scripts);
        hasUnlockScript = builtins.any (
          script: lib.hasInfix "test-tf-unlock-unit" (script.name or "")
        ) scripts;
        hasStatusScript = builtins.any (
          script: lib.hasInfix "test-tf-status-unit" (script.name or "")
        ) scripts;
      };
    expected = {
      scriptCount = 4;
      isFirstScriptValid = true;
      hasUnlockScript = true;
      hasStatusScript = true;
    };
  };

  # Test activation script generation
  test_activation_script = {
    expr =
      let
        script = opentofu.mkActivationScript {
          serviceName = "test";
          instanceName = "unit";
          terraformConfigPath = "/test/path";
        };
      in
      {
        hasText = script ? text;
        hasDeps = script ? deps;
        textNotEmpty = builtins.stringLength (script.text or "") > 0;
        hasChangeDetection = lib.hasInfix "configuration changes" (script.text or "");
      };
    expected = {
      hasText = true;
      hasDeps = true;
      textNotEmpty = true;
      hasChangeDetection = true;
    };
  };

  # Test deployment service generation
  test_deployment_service = {
    expr =
      let
        credentialMapping = {
          "admin_password" = "admin_password";
        };
        service = opentofu.mkDeploymentService {
          serviceName = "test";
          instanceName = "unit";
          terraformConfigPath = "/test/path";
          inherit credentialMapping;
          dependencies = [ "test.service" ];
        };
      in
      {
        hasService = service ? "test-terraform-deploy-unit";
        serviceHasScript = (service."test-terraform-deploy-unit" or { }) ? script;
        serviceHasCredentials =
          (service."test-terraform-deploy-unit".serviceConfig or { }) ? LoadCredential;
        credentialCount = builtins.length (
          (service."test-terraform-deploy-unit".serviceConfig or { }).LoadCredential or [ ]
        );
      };
    expected = {
      hasService = true;
      serviceHasScript = true;
      serviceHasCredentials = true;
      credentialCount = 1;
    };
  };

  # Test credential mapping
  test_credential_mapping = {
    expr =
      let
        mapping = {
          "db_pass" = "db_password";
          "api_key" = "api_secret";
        };
        credentials = opentofu.generateLoadCredentials "test-service" mapping;
      in
      {
        credentialCount = builtins.length credentials;
        firstCredential = builtins.head credentials;
        hasCorrectFormat = lib.hasInfix "/run/secrets/vars/test-service/" (builtins.head credentials);
      };
    expected = {
      credentialCount = 2;
      firstCredential = "db_pass:/run/secrets/vars/test-service/db_password";
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

  # Test terranix validation (if available)
  test_terranix_validation = {
    expr =
      let
        validConfig = {
          terraform.required_version = ">= 1.0";
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

  # Test garage init service generation
  test_garage_init_service = {
    expr =
      let
        service = opentofu.mkGarageInitService {
          serviceName = "test";
          instanceName = "unit";
        };
      in
      {
        hasService = service ? "garage-terraform-init-unit";
        serviceHasScript = (service."garage-terraform-init-unit" or { }) ? script;
        serviceHasPath = (service."garage-terraform-init-unit" or { }) ? path;
        hasGarageCommand = lib.hasInfix "garage" (
          (service."garage-terraform-init-unit" or { }).script or ""
        );
      };
    expected = {
      hasService = true;
      serviceHasScript = true;
      serviceHasPath = true;
      hasGarageCommand = true;
    };
  };

  # === GENERIC TESTS (Service-Independent) ===

  # Test generic terranix module evaluation
  test_generic_terranix_module = {
    expr =
      let
        # Create a simple generic terranix module
        simpleModule = _: {
          terraform.required_version = ">= 1.0";
          provider.null = {
            source = "hashicorp/null";
            version = "~> 3.0";
          };
          variable.test_var = {
            description = "Test variable";
            type = "string";
            default = "test";
          };
          resource.null_resource.test = {
            provisioner.local-exec = {
              command = "echo \${var.test_var}";
            };
          };
          output.test_output = {
            value = "\${null_resource.test.id}";
            description = "Test resource ID";
          };
        };

        # Evaluate the module using OpenTofu terranix utilities
        config = opentofu.evalTerranixModule {
          module = simpleModule;
          moduleArgs = { inherit lib; };
        };
      in
      {
        hasAllSections =
          config ? terraform
          && config ? provider
          && config ? variable
          && config ? resource
          && config ? output;
        terraformVersionSet = config.terraform ? required_version;
        hasNullProvider = config.provider ? null;
        hasTestVariable = config.variable ? test_var;
        hasNullResource = config.resource ? null_resource;
        hasOutput = config.output ? test_output;
        resourceCount = builtins.length (builtins.attrNames (config.resource.null_resource or { }));
      };
    expected = {
      hasAllSections = true;
      terraformVersionSet = true;
      hasNullProvider = true;
      hasTestVariable = true;
      hasNullResource = true;
      hasOutput = true;
      resourceCount = 1;
    };
  };

  # Test generic service deployment configuration
  test_generic_service_deployment = {
    expr =
      let
        # Test with a hypothetical "myservice" service
        credentialMapping = {
          "service_token" = "service_token";
          "database_password" = "db_password";
        };

        service = opentofu.mkDeploymentService {
          serviceName = "myservice";
          instanceName = "production";
          terraformConfigPath = "/test/myservice-terraform.json";
          inherit credentialMapping;
          dependencies = [
            "myservice.service"
            "database.service"
          ];
          backendType = "local";
          timeoutSec = "15m";
        };

        deploymentService = service."myservice-terraform-deploy-production";
      in
      {
        hasCorrectServiceName = service ? "myservice-terraform-deploy-production";
        hasRequiredDependencies =
          builtins.elem "myservice.service" deploymentService.requires
          && builtins.elem "database.service" deploymentService.requires;
        hasCorrectTimeout = deploymentService.serviceConfig.TimeoutStartSec == "15m";
        hasCredentialMapping = builtins.length deploymentService.serviceConfig.LoadCredential == 2;
        isOneshot = deploymentService.serviceConfig.Type == "oneshot";
        blocksDeployment = builtins.elem "multi-user.target" deploymentService.wantedBy;
      };
    expected = {
      hasCorrectServiceName = true;
      hasRequiredDependencies = true;
      hasCorrectTimeout = true;
      hasCredentialMapping = true;
      isOneshot = true;
      blocksDeployment = true;
    };
  };

  # Test terranix validation with various configurations
  test_generic_terranix_validation = {
    expr =
      let
        # Test valid configuration
        validConfig = {
          terraform.required_version = ">= 1.0";
          provider.test = {
            source = "test/provider";
          };
          resource.test_resource.example = {
            name = "test";
          };
        };

        # Test invalid configuration (missing terraform block)
        invalidConfigTest = builtins.tryEval (
          opentofu.validateTerranixConfig {
            provider.test = { };
            # Missing terraform block - should be considered valid since it's optional
          }
        );

        # Test completely empty configuration
        emptyConfigTest = builtins.tryEval (opentofu.validateTerranixConfig { });

      in
      {
        validConfigPasses = (opentofu.validateTerranixConfig validConfig) == validConfig;
        incompleteConfigHandled = invalidConfigTest.success;
        emptyConfigHandled = !emptyConfigTest.success; # Empty config should fail
      };
    expected = {
      validConfigPasses = true;
      incompleteConfigHandled = true;
      emptyConfigHandled = true;
    };
  };

  # Test S3/Garage backend configuration
  test_s3_backend_service = {
    expr =
      let
        garageService = opentofu.mkGarageInitService {
          serviceName = "testservice";
          instanceName = "test";
        };

        garageInit = garageService."garage-terraform-init-test";
      in
      {
        hasCorrectName = garageService ? "garage-terraform-init-test";
        dependsOnGarage = builtins.elem "garage.service" garageInit.requires;
        hasGarageTools = builtins.elem pkgs.garage garageInit.path;
        hasCredentialSetup = lib.hasInfix "access_key_id" garageInit.script;
        hasWorkingDirectory = garageInit.serviceConfig ? WorkingDirectory;
      };
    expected = {
      hasCorrectName = true;
      dependsOnGarage = true;
      hasGarageTools = true;
      hasCredentialSetup = true;
      hasWorkingDirectory = true;
    };
  };

  # Test multiple service pattern (verifying library can handle multiple services)
  test_multiple_services = {
    expr =
      let
        service1 = opentofu.mkHelperScripts {
          serviceName = "service1";
          instanceName = "prod";
        };
        service2 = opentofu.mkHelperScripts {
          serviceName = "service2";
          instanceName = "dev";
        };

        # Check that each service gets unique script names
        service1Names = map (script: script.name or "") service1;
        service2Names = map (script: script.name or "") service2;

        hasService1Scripts = builtins.any (name: lib.hasInfix "service1-tf-" name) service1Names;
        hasService2Scripts = builtins.any (name: lib.hasInfix "service2-tf-" name) service2Names;
        noNameCollisions = !(builtins.any (name: builtins.elem name service2Names) service1Names);

      in
      {
        service1Count = builtins.length service1;
        service2Count = builtins.length service2;
        inherit hasService1Scripts hasService2Scripts noNameCollisions;
      };
    expected = {
      service1Count = 4;
      service2Count = 4;
      hasService1Scripts = true;
      hasService2Scripts = true;
      noNameCollisions = true;
    };
  };
}
