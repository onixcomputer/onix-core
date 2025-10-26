# Terranix Module Tests - For nix-unit testing
# Tests terranix evaluation, validation, and generation functions
{
  lib ? import <nixpkgs/lib>,
  # Import terranix library functions
  # Import individual modules for detailed testing
  validation ? (import ../../terranix/validation.nix { inherit lib; }),
  eval ? (import ../../terranix/eval.nix { inherit lib; }),
  types ? (import ../../terranix/types.nix { inherit lib; }),
}:

{
  # Test terranix configuration validation
  test_terranix_validation = {
    expr =
      let
        validConfig = {
          terraform.required_version = ">= 1.0";
          provider.keycloak = {
            url = "http://localhost:8080";
            username = "\${var.admin_username}";
            password = "\${var.admin_password}";
          };
          resource.keycloak_realm.test = {
            realm = "test";
            enabled = true;
          };
        };

        emptyConfig = { };
        invalidConfig = "not an attribute set";

        validResult = validation.validateTerranixConfig validConfig;

        # Test that invalid configs throw errors
        emptyTest = builtins.tryEval (validation.validateTerranixConfig emptyConfig);
        invalidTest = builtins.tryEval (validation.validateTerranixConfig invalidConfig);
      in
      {
        validationPassed = validResult == validConfig;
        emptyFails = !emptyTest.success;
        invalidFails = !invalidTest.success;
        hasAllSections = validResult ? terraform && validResult ? provider && validResult ? resource;
      };
    expected = {
      validationPassed = true;
      emptyFails = true;
      invalidFails = true;
      hasAllSections = true;
    };
  };

  # Test terranix module evaluation
  test_terranix_module_evaluation = {
    expr =
      let
        # Simple function-based terranix module
        simpleModule = _: {
          terraform.required_version = ">= 1.0";
          provider.null = {
            source = "hashicorp/null";
            version = "~> 3.0";
          };
          resource.null_resource.test = {
            provisioner.local-exec.command = "echo test";
          };
        };

        # Module with arguments
        moduleWithArgs =
          {
            adminUser ? "admin",
          }:
          {
            terraform.required_version = ">= 1.0";
            variable.admin_user = {
              description = "Admin username";
              type = "string";
              default = adminUser;
            };
          };

        # Evaluate simple module
        evalResult = eval.evalTerranixModule {
          module = simpleModule;
          moduleArgs = { };
        };

        # Evaluate module with arguments
        evalWithArgs = eval.evalTerranixModule {
          module = moduleWithArgs;
          moduleArgs = {
            adminUser = "customadmin";
          };
        };

        # Evaluate with debug mode
        evalWithDebug = eval.evalTerranixModule {
          module = simpleModule;
          moduleArgs = { };
          debug = true;
        };
      in
      {
        hasProviders = evalResult ? provider;
        hasResources = evalResult ? resource;
        hasTerraform = evalResult ? terraform;
        customUserDefault = evalWithArgs.variable.admin_user.default;
        debugHasInfo = evalWithDebug ? _debug;
        debugHasSource = evalWithDebug._debug ? moduleSource;
      };
    expected = {
      hasProviders = true;
      hasResources = true;
      hasTerraform = true;
      customUserDefault = "customadmin";
      debugHasInfo = true;
      debugHasSource = true;
    };
  };

  # Test error formatting
  test_error_formatting = {
    expr =
      let
        validationError = "Terranix validation failed:\nInvalid terraform block structure";
        evalError = "error: some evaluation error";
        unknownError = "some unknown error";

        formattedValidation = validation.formatTerranixError validationError;
        formattedEval = validation.formatTerranixError evalError;
        formattedUnknown = validation.formatTerranixError unknownError;
      in
      {
        validationFormatted = lib.hasPrefix "Terranix Configuration Validation Error:" formattedValidation;
        evalFormatted = lib.hasPrefix "Terranix Module Evaluation Error:" formattedEval;
        unknownFormatted = lib.hasPrefix "Terranix Error:" formattedUnknown;
        validationHasDetail = lib.hasInfix "Invalid terraform block structure" formattedValidation;
        evalHasOriginal = lib.hasInfix "some evaluation error" formattedEval;
      };
    expected = {
      validationFormatted = true;
      evalFormatted = true;
      unknownFormatted = true;
      validationHasDetail = true;
      evalHasOriginal = true;
    };
  };

  # Test type definitions
  test_terranix_types = {
    expr =
      let
        # Test configuration type structure
        configTypeOptions = types.terranixConfigType.getSubOptions [ ];
        requiredOptions = [
          "terraform"
          "provider"
          "variable"
          "resource"
          "output"
        ];
        allOptionsExist = builtins.all (opt: builtins.hasAttr opt configTypeOptions) requiredOptions;

        # Test deployment service options
        deploymentOptions = types.deploymentServiceOptionsType.getSubOptions [ ];
        deploymentHasServiceName = deploymentOptions ? serviceName;
        deploymentHasInstance = deploymentOptions ? instanceName;
        deploymentHasCredentials = deploymentOptions ? credentialMapping;
      in
      {
        configHasAllOptions = allOptionsExist;
        configOptionCount = builtins.length (builtins.attrNames configTypeOptions);
        deploymentHasRequired = deploymentHasServiceName && deploymentHasInstance;
        deploymentHasOptional = deploymentHasCredentials;
        deploymentOptionCount = builtins.length (builtins.attrNames deploymentOptions);
      };
    expected = {
      configHasAllOptions = true;
      configOptionCount = 5;
      deploymentHasRequired = true;
      deploymentHasOptional = true;
      deploymentOptionCount = 13;
    };
  };

  # Test complex module evaluation scenarios
  test_complex_module_evaluation = {
    expr =
      let
        # Module that depends on lib functions
        complexModule =
          { lib }:
          {
            terraform.required_version = ">= 1.0";
            variable = lib.genAttrs [ "admin_user" "admin_pass" ] (name: {
              description = "Variable: ${name}";
              type = "string";
            });
            resource.keycloak_realm = lib.genAttrs [ "dev" "prod" ] (env: {
              realm = env;
              enabled = true;
              display_name = "Environment: ${env}";
            });
          };

        # Evaluate with lib
        evalResult = eval.evalTerranixModule {
          module = complexModule;
          moduleArgs = { inherit lib; };
        };

        variables = builtins.attrNames evalResult.variable;
        realms = builtins.attrNames evalResult.resource.keycloak_realm;
      in
      {
        variableCount = builtins.length variables;
        realmCount = builtins.length realms;
        hasAdminUser = builtins.elem "admin_user" variables;
        hasAdminPass = builtins.elem "admin_pass" variables;
        hasDevRealm = builtins.elem "dev" realms;
        hasProdRealm = builtins.elem "prod" realms;
        devRealmName = evalResult.resource.keycloak_realm.dev.display_name;
      };
    expected = {
      variableCount = 2;
      realmCount = 2;
      hasAdminUser = true;
      hasAdminPass = true;
      hasDevRealm = true;
      hasProdRealm = true;
      devRealmName = "Environment: dev";
    };
  };

  # Test validation edge cases
  test_validation_edge_cases = {
    expr =
      let
        # Config with only terraform block
        terraformOnly = {
          terraform = {
            required_version = ">= 1.0";
            required_providers = {
              null = {
                source = "hashicorp/null";
                version = "~> 3.0";
              };
            };
          };
        };

        # Config with only resource block
        resourceOnly = {
          resource.null_resource.test = {
            provisioner.local-exec.command = "echo test";
          };
        };

        # Config with invalid terraform block
        invalidTerraform = {
          terraform = "not an attribute set";
        };

        terraformOnlyValid = builtins.tryEval (validation.validateTerranixConfig terraformOnly);
        resourceOnlyValid = builtins.tryEval (validation.validateTerranixConfig resourceOnly);
        invalidTerraformValid = builtins.tryEval (validation.validateTerranixConfig invalidTerraform);
      in
      {
        terraformOnlyPasses = terraformOnlyValid.success;
        resourceOnlyPasses = resourceOnlyValid.success;
        invalidTerraformFails = !invalidTerraformValid.success;
        terraformOnlyHasRequiredProviders = terraformOnlyValid.value.terraform ? required_providers;
      };
    expected = {
      terraformOnlyPasses = true;
      resourceOnlyPasses = false; # Should fail - resources without required_providers
      invalidTerraformFails = true;
      terraformOnlyHasRequiredProviders = true;
    };
  };

  # Test module evaluation with validation disabled
  test_evaluation_without_validation = {
    expr =
      let
        # Module that produces invalid config
        invalidModule = _: {
          terraform = "invalid structure";
          provider = {
            keycloak = {
              url = "http://localhost:8080";
            };
          };
        };

        # Evaluate with validation disabled
        evalWithoutValidation = eval.evalTerranixModule {
          module = invalidModule;
          moduleArgs = { };
          validate = false;
        };

        # This would fail with validation enabled
        evalWithValidation = builtins.tryEval (
          eval.evalTerranixModule {
            module = invalidModule;
            moduleArgs = { };
            validate = true;
          }
        );
      in
      {
        withoutValidationWorks = builtins.isAttrs evalWithoutValidation;
        withValidationFails = !evalWithValidation.success;
        hasInvalidTerraform = evalWithoutValidation.terraform == "invalid structure";
        hasValidProvider = builtins.isAttrs evalWithoutValidation.provider;
      };
    expected = {
      withoutValidationWorks = true;
      withValidationFails = true;
      hasInvalidTerraform = true;
      hasValidProvider = true;
    };
  };

  # Test string and path module evaluation
  test_module_types = {
    expr =
      let
        # Test attribute set module (direct config)
        attrSetModule = {
          terraform = {
            required_version = ">= 1.0";
            required_providers = {
              null = {
                source = "hashicorp/null";
                version = "~> 3.0";
              };
            };
          };
          resource.null_resource.direct = {
            provisioner.local-exec.command = "echo direct";
          };
        };

        # Evaluate attribute set directly
        evalAttrSet = eval.evalTerranixModule {
          module = attrSetModule;
          moduleArgs = { };
        };

        # Function module
        functionModule = _args: attrSetModule;

        # Evaluate function module
        evalFunction = eval.evalTerranixModule {
          module = functionModule;
          moduleArgs = { };
        };
      in
      {
        attrSetHasResource = evalAttrSet ? resource;
        functionHasResource = evalFunction ? resource;
        attrSetResourceName = builtins.head (builtins.attrNames evalAttrSet.resource.null_resource);
        functionResourceName = builtins.head (builtins.attrNames evalFunction.resource.null_resource);
        bothEqual = evalAttrSet == evalFunction;
      };
    expected = {
      attrSetHasResource = true;
      functionHasResource = true;
      attrSetResourceName = "direct";
      functionResourceName = "direct";
      bothEqual = true;
    };
  };

  # Test debug information structure
  test_debug_information = {
    expr =
      let
        testModule =
          {
            testArg ? "default",
          }:
          {
            terraform.required_version = ">= 1.0";
            variable.test_var = {
              default = testArg;
            };
          };

        debugResult = eval.evalTerranixModule {
          module = testModule;
          moduleArgs = {
            testArg = "debug_value";
          };
          debug = true;
        };

        nonDebugResult = eval.evalTerranixModule {
          module = testModule;
          moduleArgs = {
            testArg = "normal_value";
          };
          debug = false;
        };
      in
      {
        debugHasInfo = debugResult ? _debug;
        debugHasSource = debugResult._debug ? moduleSource;
        debugHasArgs = debugResult._debug ? evaluationArgs;
        nonDebugNoInfo = !(nonDebugResult ? _debug);
        debugArgCount = builtins.length debugResult._debug.evaluationArgs;
        debugHasTestArg = builtins.elem "testArg" debugResult._debug.evaluationArgs;
        bothHaveVariable = debugResult ? variable && nonDebugResult ? variable;
      };
    expected = {
      debugHasInfo = true;
      debugHasSource = true;
      debugHasArgs = true;
      nonDebugNoInfo = true;
      debugArgCount = 1;
      debugHasTestArg = true;
      bothHaveVariable = true;
    };
  };

  # Test multiple provider configurations
  test_multiple_providers = {
    expr =
      let
        multiProviderModule = _: {
          terraform = {
            required_version = ">= 1.0";
            required_providers = {
              keycloak = {
                source = "mrparkers/keycloak";
                version = "~> 4.0";
              };
              postgresql = {
                source = "cyrilgdn/postgresql";
                version = "~> 1.0";
              };
            };
          };
          provider = {
            keycloak = {
              url = "http://localhost:8080";
              username = "\${var.keycloak_admin}";
              password = "\${var.keycloak_password}";
            };
            postgresql = {
              host = "localhost";
              port = 5432;
              database = "keycloak";
              username = "\${var.db_user}";
              password = "\${var.db_password}";
            };
          };
        };

        evalResult = eval.evalTerranixModule {
          module = multiProviderModule;
          moduleArgs = { };
        };

        providerNames = builtins.attrNames evalResult.provider;
        requiredProviders = builtins.attrNames evalResult.terraform.required_providers;
      in
      {
        providerCount = builtins.length providerNames;
        requiredProviderCount = builtins.length requiredProviders;
        hasKeycloak = builtins.elem "keycloak" providerNames;
        hasPostgresql = builtins.elem "postgresql" providerNames;
        keycloakHasUrl = evalResult.provider.keycloak ? url;
        postgresqlHasHost = evalResult.provider.postgresql ? host;
        allProvidersRequired = builtins.all (p: builtins.elem p requiredProviders) providerNames;
      };
    expected = {
      providerCount = 2;
      requiredProviderCount = 2;
      hasKeycloak = true;
      hasPostgresql = true;
      keycloakHasUrl = true;
      postgresqlHasHost = true;
      allProvidersRequired = true;
    };
  };
}
