# Backend Configuration Tests - For nix-unit testing
# Tests backend module functions and configurations
{
  lib ? import <nixpkgs/lib>,
  pkgs ? import <nixpkgs> { },
  # Import backend modules
  backends ? (import ../../backends/default.nix { inherit lib pkgs; }),
  localBackend ? (import ../../backends/local.nix { inherit lib pkgs; }),
  s3Backend ? (import ../../backends/s3.nix { inherit lib pkgs; }),
# Import pure functions for testing utilities
}:

{
  # Test local backend configuration generation
  test_local_backend_config = {
    expr =
      let
        localConfig = localBackend.generateLocalBackendConfig;
        backendResult = localBackend.mkLocalBackend {
          serviceName = "test-service";
          instanceName = "unit";
        };
      in
      {
        configIsString = builtins.isString localConfig;
        configHasLocalKeyword = lib.hasInfix "local" localConfig;
        configHasTerraformBlock = lib.hasInfix "terraform" localConfig;
        configHasBackendBlock = lib.hasInfix "backend" localConfig;
        configHasStatePath = lib.hasInfix "terraform.tfstate" localConfig;
        backendHasType = backendResult.backendType == "local";
        backendHasScript = builtins.isString backendResult.backendScript;
        backendHasStateDir = builtins.isString backendResult.stateDirectory;
        backendNoServices = backendResult.additionalServices == { };
        backendNoEnvVars = backendResult.environmentVariables == { };
      };
    expected = {
      configIsString = true;
      configHasLocalKeyword = true;
      configHasTerraformBlock = true;
      configHasBackendBlock = true;
      configHasStatePath = true;
      backendHasType = true;
      backendHasScript = true;
      backendHasStateDir = true;
      backendNoServices = true;
      backendNoEnvVars = true;
    };
  };

  # Test S3 backend configuration generation
  test_s3_backend_config = {
    expr =
      let
        s3Config = s3Backend.generateS3BackendConfig {
          serviceName = "keycloak";
          instanceName = "prod";
        };
        backendResult = s3Backend.mkS3Backend {
          serviceName = "keycloak";
          instanceName = "prod";
        };
      in
      {
        configIsString = builtins.isString s3Config;
        configHasS3Keyword = lib.hasInfix "s3" s3Config;
        configHasEndpoint = lib.hasInfix "endpoint" s3Config;
        configHasBucket = lib.hasInfix "terraform-state" s3Config;
        configHasKey = lib.hasInfix "keycloak/prod/terraform.tfstate" s3Config;
        configHasRegion = lib.hasInfix "garage" s3Config;
        backendHasType = backendResult.backendType == "s3";
        backendHasScript = builtins.isString backendResult.backendScript;
        backendHasServices = backendResult.additionalServices != { };
        backendHasEnvVars = backendResult.environmentVariables != { };
        backendHasPreSetup = builtins.isString backendResult.preSetupScript;
      };
    expected = {
      configIsString = true;
      configHasS3Keyword = true;
      configHasEndpoint = true;
      configHasBucket = true;
      configHasKey = true;
      configHasRegion = true;
      backendHasType = true;
      backendHasScript = true;
      backendHasServices = true;
      backendHasEnvVars = true;
      backendHasPreSetup = true;
    };
  };

  # Test unified backend creation
  test_unified_backend_creation = {
    expr =
      let
        localResult = backends.mkBackend {
          serviceName = "test";
          instanceName = "unit";
          backendType = "local";
        };
        s3Result = backends.mkBackend {
          serviceName = "test";
          instanceName = "unit";
          backendType = "s3";
        };
        # Test invalid backend type
        invalidTest = builtins.tryEval (
          backends.mkBackend {
            serviceName = "test";
            instanceName = "unit";
            backendType = "invalid";
          }
        );
      in
      {
        localType = localResult.backendType;
        s3Type = s3Result.backendType;
        localHasLocalConfig = lib.hasInfix "local" localResult.backendConfig;
        s3HasS3Config = lib.hasInfix "s3" s3Result.backendConfig;
        localNoServices = localResult.additionalServices == { };
        s3HasServices = s3Result.additionalServices != { };
        invalidFails = !invalidTest.success;
      };
    expected = {
      localType = "local";
      s3Type = "s3";
      localHasLocalConfig = true;
      s3HasS3Config = true;
      localNoServices = true;
      s3HasServices = true;
      invalidFails = true;
    };
  };

  # Test backend auto-detection
  test_backend_auto_detection = {
    expr =
      let
        localAutoDetect = backends.autoDetectBackend {
          serviceName = "simple";
          instanceName = "test";
          requiresSharedState = false;
          hasGarageService = false;
        };
        s3AutoDetect = backends.autoDetectBackend {
          serviceName = "shared";
          instanceName = "prod";
          requiresSharedState = true;
          hasGarageService = true;
        };
        localButNoGarage = backends.autoDetectBackend {
          serviceName = "shared";
          instanceName = "test";
          requiresSharedState = true;
          hasGarageService = false;
        };
      in
      {
        localDetectedType = localAutoDetect.backendType;
        s3DetectedType = s3AutoDetect.backendType;
        localButNoGarageType = localButNoGarage.backendType;
        localDetectedIsLocal = localAutoDetect.backendType == "local";
        s3DetectedIsS3 = s3AutoDetect.backendType == "s3";
      };
    expected = {
      localDetectedType = "local";
      s3DetectedType = "s3";
      localButNoGarageType = "local";
      localDetectedIsLocal = true;
      s3DetectedIsS3 = true;
    };
  };

  # Test backend validation
  test_backend_validation = {
    expr =
      let
        validBackend = {
          backendType = "local";
          backendConfig = "config";
          backendScript = "script";
          stateDirectory = "/var/lib/test";
          additionalServices = { };
        };
        invalidBackend = {
          backendType = "invalid";
          # Missing required fields
        };

        validTest = builtins.tryEval (backends.validateBackend validBackend);
        invalidTest = builtins.tryEval (backends.validateBackend invalidBackend);
      in
      {
        validPasses = validTest.success;
        invalidFails = !invalidTest.success;
        validReturnsSame = validTest.success && validTest.value == validBackend;
      };
    expected = {
      validPasses = true;
      invalidFails = true;
      validReturnsSame = true;
    };
  };

  # Test backend service generation
  test_backend_services = {
    expr =
      let
        localServices = backends.getBackendServices {
          backendType = "local";
          serviceName = "test";
          instanceName = "unit";
        };
        s3Services = backends.getBackendServices {
          backendType = "s3";
          serviceName = "test";
          instanceName = "unit";
        };
      in
      {
        localServicesEmpty = localServices == { };
        s3ServicesNotEmpty = s3Services != { };
        s3HasGarageInit = s3Services ? "garage-terraform-init-unit";
      };
    expected = {
      localServicesEmpty = true;
      s3ServicesNotEmpty = true;
      s3HasGarageInit = true;
    };
  };

  # Test backend utility functions
  test_backend_utilities = {
    expr =
      let
        supportedBackends = backends.listSupportedBackends;
        isLocalSupported = backends.isBackendSupported "local";
        isS3Supported = backends.isBackendSupported "s3";
        isInvalidSupported = backends.isBackendSupported "invalid";

        localModule = backends.getBackendModule "local";
        invalidModuleTest = builtins.tryEval (backends.getBackendModule "invalid");
      in
      {
        supportedCount = builtins.length supportedBackends;
        hasLocal = builtins.elem "local" supportedBackends;
        hasS3 = builtins.elem "s3" supportedBackends;
        localSupported = isLocalSupported;
        s3Supported = isS3Supported;
        invalidNotSupported = !isInvalidSupported;
        localModuleExists = localModule ? mkLocalBackend;
        invalidModuleFails = !invalidModuleTest.success;
      };
    expected = {
      supportedCount = 2;
      hasLocal = true;
      hasS3 = true;
      localSupported = true;
      s3Supported = true;
      invalidNotSupported = true;
      localModuleExists = true;
      invalidModuleFails = true;
    };
  };

  # Test Garage backend init service generation
  test_garage_init_service = {
    expr =
      let
        garageService = s3Backend.mkTerranixGarageBackend {
          serviceName = "keycloak";
          instanceName = "prod";
        };
        serviceName = "garage-terraform-init-prod";
        serviceConfig = garageService.${serviceName};
      in
      {
        hasService = garageService ? ${serviceName};
        hasDescription = serviceConfig ? description;
        hasAfter = serviceConfig ? after;
        hasRequires = serviceConfig ? requires;
        hasScript = serviceConfig ? script;
        descriptionCorrect = lib.hasInfix "keycloak" serviceConfig.description;
        afterIncludesGarage = builtins.elem "garage.service" serviceConfig.after;
        requiresIncludesGarage = builtins.elem "garage.service" serviceConfig.requires;
        scriptHasGarage = lib.hasInfix "garage" serviceConfig.script;
        scriptHasBucket = lib.hasInfix "terraform-state" serviceConfig.script;
        scriptHasCredentials = lib.hasInfix "access_key_id" serviceConfig.script;
      };
    expected = {
      hasService = true;
      hasDescription = true;
      hasAfter = true;
      hasRequires = true;
      hasScript = true;
      descriptionCorrect = true;
      afterIncludesGarage = true;
      requiresIncludesGarage = true;
      scriptHasGarage = true;
      scriptHasBucket = true;
      scriptHasCredentials = true;
    };
  };

  # Test custom S3 backend configuration
  test_custom_s3_backend = {
    expr =
      let
        customBackend = s3Backend.mkCustomS3Backend {
          serviceName = "test";
          instanceName = "custom";
          endpoint = "https://s3.custom.com";
          bucket = "custom-bucket";
          region = "us-west-2";
        };
      in
      {
        hasCustomEndpoint = lib.hasInfix "s3.custom.com" customBackend.backendConfig;
        hasCustomBucket = lib.hasInfix "custom-bucket" customBackend.backendConfig;
        hasCustomRegion = lib.hasInfix "us-west-2" customBackend.backendConfig;
        hasCorrectKey = lib.hasInfix "test/custom/terraform.tfstate" customBackend.backendConfig;
        backendTypeIsS3 = customBackend.backendType == "s3";
        hasServices = customBackend.additionalServices != { };
        hasEnvVars = customBackend.environmentVariables != { };
        hasPreSetup = builtins.stringLength customBackend.preSetupScript > 0;
      };
    expected = {
      hasCustomEndpoint = true;
      hasCustomBucket = true;
      hasCustomRegion = true;
      hasCorrectKey = true;
      backendTypeIsS3 = true;
      hasServices = true;
      hasEnvVars = true;
      hasPreSetup = true;
    };
  };

  # Test backend environment and pre-setup helpers
  test_backend_helpers = {
    expr =
      let
        localBackend = backends.mkBackend {
          serviceName = "test";
          instanceName = "unit";
          backendType = "local";
        };
        s3Backend = backends.mkBackend {
          serviceName = "test";
          instanceName = "unit";
          backendType = "s3";
        };

        localEnv = backends.getBackendEnvironment localBackend;
        s3Env = backends.getBackendEnvironment s3Backend;
        localPreSetup = backends.getBackendPreSetup localBackend;
        s3PreSetup = backends.getBackendPreSetup s3Backend;
      in
      {
        localEnvEmpty = localEnv == { };
        s3EnvNotEmpty = s3Env != { };
        s3EnvHasAccessKey = s3Env ? AWS_ACCESS_KEY_ID;
        s3EnvHasSecretKey = s3Env ? AWS_SECRET_ACCESS_KEY;
        localPreSetupEmpty = localPreSetup == "";
        s3PreSetupNotEmpty = s3PreSetup != "";
        s3PreSetupHasCredCheck = lib.hasInfix "credentials not found" s3PreSetup;
      };
    expected = {
      localEnvEmpty = true;
      s3EnvNotEmpty = true;
      s3EnvHasAccessKey = true;
      s3EnvHasSecretKey = true;
      localPreSetupEmpty = true;
      s3PreSetupNotEmpty = true;
      s3PreSetupHasCredCheck = true;
    };
  };

  # Test backend debugging and introspection
  test_backend_debugging = {
    expr =
      let
        localBackend = backends.mkBackend {
          serviceName = "debug";
          instanceName = "test";
          backendType = "local";
        };
        s3Backend = backends.mkBackend {
          serviceName = "debug";
          instanceName = "test";
          backendType = "s3";
        };

        localDebug = backends.debugBackend localBackend;
        s3Debug = backends.debugBackend s3Backend;
      in
      {
        localDebugType = localDebug.backendType;
        s3DebugType = s3Debug.backendType;
        localNoAdditionalServices = !localDebug.hasAdditionalServices;
        s3HasAdditionalServices = s3Debug.hasAdditionalServices;
        localStateDir = localDebug.stateDirectory;
        s3StateDir = s3Debug.stateDirectory;
        localNoEnvVars = builtins.length localDebug.environmentVariables == 0;
        s3HasEnvVars = builtins.length s3Debug.environmentVariables > 0;
        localNoPreSetup = !localDebug.hasPreSetupScript;
        s3HasPreSetup = s3Debug.hasPreSetupScript;
      };
    expected = {
      localDebugType = "local";
      s3DebugType = "s3";
      localNoAdditionalServices = true;
      s3HasAdditionalServices = true;
      localStateDir = "/var/lib/debug-test-terraform";
      s3StateDir = "/var/lib/debug-test-terraform";
      localNoEnvVars = true;
      s3HasEnvVars = true;
      localNoPreSetup = true;
      s3HasPreSetup = true;
    };
  };

  # Test S3 credential path generation
  test_s3_credential_paths = {
    expr =
      let
        credPaths = s3Backend.mkS3CredentialPaths "production";
      in
      {
        hasAccessKeyPath = credPaths ? accessKeyPath;
        hasSecretKeyPath = credPaths ? secretKeyPath;
        accessKeyCorrect = credPaths.accessKeyPath == "/var/lib/garage-terraform-production/access_key_id";
        secretKeyCorrect =
          credPaths.secretKeyPath == "/var/lib/garage-terraform-production/secret_access_key";
      };
    expected = {
      hasAccessKeyPath = true;
      hasSecretKeyPath = true;
      accessKeyCorrect = true;
      secretKeyCorrect = true;
    };
  };
}
