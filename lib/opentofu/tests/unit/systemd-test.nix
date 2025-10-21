# Terranix SystemD Module Tests - For nix-unit testing
# Tests terranix-focused systemd functions that don't create derivations
{
  lib ? import <nixpkgs/lib>,
  pkgs ? import <nixpkgs> { },
  # Import systemd library functions
  systemd ? (import ../../systemd/default.nix { inherit lib pkgs; }),
  # Import health checks module
  healthChecks ? (import ../../systemd/health-checks.nix { inherit lib; }),
  # Import pure functions for testing utilities
  pure ? (import ../../lib-pure.nix { inherit lib; }),
}:

{
  # Test health check strategy retrieval
  test_health_check_strategies = {
    expr =
      let
        strategies = healthChecks.healthCheckStrategies;
        keycloakStrategy = strategies.keycloak;
        garageStrategy = strategies.garage;
        genericStrategy = strategies.generic;
      in
      {
        hasKeycloak = strategies ? keycloak;
        hasGarage = strategies ? garage;
        hasGeneric = strategies ? generic;
        keycloakMaxAttempts = keycloakStrategy.maxAttempts;
        keycloakPhaseCount = builtins.length keycloakStrategy.phases;
        garageStabilization = garageStrategy.stabilizationWait;
        genericDescription = genericStrategy.description;
      };
    expected = {
      hasKeycloak = true;
      hasGarage = true;
      hasGeneric = true;
      keycloakMaxAttempts = 90;
      keycloakPhaseCount = 3;
      garageStabilization = 5;
      genericDescription = "Generic HTTP service";
    };
  };

  # Test available strategies list
  test_available_strategies = {
    expr =
      let
        strategies = healthChecks.getAvailableStrategies;
        sortedStrategies = builtins.sort (a: b: a < b) strategies;
      in
      {
        strategyCount = builtins.length strategies;
        hasKeycloak = builtins.elem "keycloak" strategies;
        hasGarage = builtins.elem "garage" strategies;
        hasGeneric = builtins.elem "generic" strategies;
        firstStrategy = builtins.head sortedStrategies;
      };
    expected = {
      strategyCount = 3;
      hasKeycloak = true;
      hasGarage = true;
      hasGeneric = true;
      firstStrategy = "garage";
    };
  };

  # Test health check strategy validation
  test_strategy_validation = {
    expr =
      let
        validStrategy = {
          description = "Test service";
          maxAttempts = 30;
          sleepInterval = 2;
          phases = [
            {
              name = "health";
              description = "Health check";
              url = "http://localhost:8080/health";
              required = true;
            }
          ];
          stabilizationWait = 5;
        };

        validated = healthChecks.validateHealthCheckStrategy validStrategy;

        # Test that invalid strategies throw errors
        invalidTest = builtins.tryEval (
          healthChecks.validateHealthCheckStrategy {
            description = "Incomplete strategy";
            # Missing required fields
          }
        );
      in
      {
        validationWorks = validated == validStrategy;
        invalidFails = !invalidTest.success;
        hasDescription = validated ? description;
        hasMaxAttempts = validated ? maxAttempts;
        hasPhases = validated ? phases;
      };
    expected = {
      validationWorks = true;
      invalidFails = true;
      hasDescription = true;
      hasMaxAttempts = true;
      hasPhases = true;
    };
  };

  # Test health check script generation
  test_health_check_generation = {
    expr =
      let
        keycloakScript = healthChecks.generateHealthChecks "keycloak";
        garageScript = healthChecks.generateHealthChecks "garage";
        unknownScript = healthChecks.generateHealthChecks "unknown-service";
      in
      {
        keycloakIsString = builtins.isString keycloakScript;
        garageIsString = builtins.isString garageScript;
        unknownIsString = builtins.isString unknownScript;
        keycloakHasOIDC = lib.hasInfix "OIDC endpoints" keycloakScript;
        garageHasS3 = lib.hasInfix "S3 API endpoint" garageScript;
        unknownUsesGeneric = lib.hasInfix "Generic HTTP service" unknownScript;
        keycloakHasSystemctl = lib.hasInfix "systemctl is-active keycloak.service" keycloakScript;
        garageHasHealthCheck = lib.hasInfix "127.0.0.1:3903/health" garageScript;
      };
    expected = {
      keycloakIsString = true;
      garageIsString = true;
      unknownIsString = true;
      keycloakHasOIDC = true;
      garageHasS3 = true;
      unknownUsesGeneric = true;
      keycloakHasSystemctl = true;
      garageHasHealthCheck = true;
    };
  };

  # Test strategy registration
  test_strategy_registration = {
    expr =
      let
        customStrategy = {
          description = "Custom test service";
          maxAttempts = 20;
          sleepInterval = 3;
          phases = [
            {
              name = "custom";
              description = "Custom health check";
              url = "http://localhost:9999/status";
              required = true;
            }
          ];
          stabilizationWait = 10;
        };

        updatedStrategies = healthChecks.registerHealthCheckStrategy "custom" customStrategy;
        originalCount = builtins.length (builtins.attrNames healthChecks.healthCheckStrategies);
        updatedCount = builtins.length (builtins.attrNames updatedStrategies);
      in
      {
        inherit originalCount;
        inherit updatedCount;
        hasCustom = updatedStrategies ? custom;
        customDescription = updatedStrategies.custom.description;
        stillHasKeycloak = updatedStrategies ? keycloak;
      };
    expected = {
      originalCount = 3;
      updatedCount = 4;
      hasCustom = true;
      customDescription = "Custom test service";
      stillHasKeycloak = true;
    };
  };

  # Test terranix activation script generation (pure parts)
  test_activation_script_structure = {
    expr =
      let
        # Mock terranix module for testing

        script = systemd.mkTerranixActivation {
          serviceName = "test-service";
          instanceName = "unit";
          terraformConfigPath = "/mock/config.json";
        };
      in
      {
        hasText = script ? text;
        hasDeps = script ? deps;
        textIsString = builtins.isString script.text;
        depsIsList = builtins.isList script.deps;
        hasSetupSecrets = builtins.elem "setupSecrets" script.deps;
        textHasServiceName = lib.hasInfix "test-service" script.text;
        textHasStateDir = lib.hasInfix "/var/lib/test-service-unit-terraform" script.text;
        textHasHashCheck = lib.hasInfix "sha256sum" script.text;
      };
    expected = {
      hasText = true;
      hasDeps = true;
      textIsString = true;
      depsIsList = true;
      hasSetupSecrets = true;
      textHasServiceName = true;
      textHasStateDir = true;
      textHasHashCheck = true;
    };
  };

  # Test terranix script structure validation
  test_terranix_scripts_structure = {
    expr =
      let
        scripts = systemd.mkTerranixScripts {
          serviceName = "test-service";
          instanceName = "unit";
        };
      in
      {
        scriptCount = builtins.length scripts;
        allAreDerivations = builtins.all (
          script: builtins.isAttrs script && script ? type && script.type == "derivation"
        ) scripts;
        # Check script names by examining the derivation names
        scriptNames = map (script: script.name) scripts;
      };
    expected = {
      scriptCount = 4;
      allAreDerivations = true;
      scriptNames = [
        "test-service-tf-unlock-unit"
        "test-service-tf-status-unit"
        "test-service-tf-apply-unit"
        "test-service-tf-logs-unit"
      ];
    };
  };

  # Test terranix script name generation using pure functions
  test_terranix_script_names = {
    expr =
      let
        serviceName = "myservice";
        instanceName = "prod";
      in
      {
        unlockScript = pure.makeUnlockScriptName serviceName instanceName;
        statusScript = pure.makeStatusScriptName serviceName instanceName;
        applyScript = pure.makeApplyScriptName serviceName instanceName;
        logsScript = pure.makeLogsScriptName serviceName instanceName;
      };
    expected = {
      unlockScript = "myservice-tf-unlock-prod";
      statusScript = "myservice-tf-status-prod";
      applyScript = "myservice-tf-apply-prod";
      logsScript = "myservice-tf-logs-prod";
    };
  };

  # Test state directory and file path generation
  test_state_paths = {
    expr =
      let
        serviceName = "keycloak";
        instanceName = "production";
      in
      {
        stateDir = pure.makeStateDirectory serviceName instanceName;
        lockFile = pure.makeLockFile serviceName instanceName;
        lockInfoFile = pure.makeLockInfoFile serviceName instanceName;
        deployCompleteFile = pure.makeDeployCompleteFile serviceName instanceName;
        deploymentServiceName = pure.makeDeploymentServiceName serviceName instanceName;
      };
    expected = {
      stateDir = "/var/lib/keycloak-production-terraform";
      lockFile = "/var/lib/keycloak-production-terraform/.terraform.lock";
      lockInfoFile = "/var/lib/keycloak-production-terraform/.terraform.lock.info";
      deployCompleteFile = "/var/lib/keycloak-production-terraform/.deploy-complete";
      deploymentServiceName = "keycloak-terraform-deploy-production";
    };
  };

  # Test health check phase structure validation
  test_health_check_phases = {
    expr =
      let
        keycloakPhases = healthChecks.healthCheckStrategies.keycloak.phases;
        garagePhases = healthChecks.healthCheckStrategies.garage.phases;

        # Extract phase information
        keycloakPhaseNames = map (p: p.name) keycloakPhases;
        keycloakRequiredPhases = builtins.filter (p: p.required) keycloakPhases;

        garageOptionalPhases = builtins.filter (p: !p.required) garagePhases;
      in
      {
        keycloakPhaseCount = builtins.length keycloakPhases;
        inherit keycloakPhaseNames;
        keycloakRequiredCount = builtins.length keycloakRequiredPhases;
        garageOptionalCount = builtins.length garageOptionalPhases;
        allKeycloakPhasesHaveUrls = builtins.all (p: p.url != null) keycloakPhases;
        allPhasesHaveNames = builtins.all (p: p ? name) (keycloakPhases ++ garagePhases);
      };
    expected = {
      keycloakPhaseCount = 3;
      keycloakPhaseNames = [
        "startup"
        "readiness"
        "oidc"
      ];
      keycloakRequiredCount = 3;
      garageOptionalCount = 1;
      allKeycloakPhasesHaveUrls = true;
      allPhasesHaveNames = true;
    };
  };

  # Test health check script command generation
  test_health_check_commands = {
    expr =
      let
        keycloakScript = healthChecks.generateHealthChecks "keycloak";
        garageScript = healthChecks.generateHealthChecks "garage";
      in
      {
        keycloakHasCurlCommands = lib.hasInfix "curl -sf" keycloakScript;
        keycloakHasStartupCheck = lib.hasInfix "9000/management/health/started" keycloakScript;
        keycloakHasReadinessCheck = lib.hasInfix "9000/management/health/ready" keycloakScript;
        keycloakHasOIDCCheck = lib.hasInfix "8080/realms/master/protocol/openid-connect/certs" keycloakScript;
        garageHasHealthCheck = lib.hasInfix "3903/health" garageScript;
        garageHasS3Check = lib.hasInfix "3900/" garageScript;
        bothHaveSystemctl =
          lib.hasInfix "systemctl is-active" keycloakScript
          && lib.hasInfix "systemctl is-active" garageScript;
        bothHaveTimestamp =
          lib.hasInfix "date -Iseconds" keycloakScript && lib.hasInfix "date -Iseconds" garageScript;
      };
    expected = {
      keycloakHasCurlCommands = true;
      keycloakHasStartupCheck = true;
      keycloakHasReadinessCheck = true;
      keycloakHasOIDCCheck = true;
      garageHasHealthCheck = true;
      garageHasS3Check = true;
      bothHaveSystemctl = true;
      bothHaveTimestamp = true;
    };
  };

  # Test error handling and edge cases
  test_error_handling = {
    expr =
      let
        # Test activation script with missing parameters
        invalidActivationTest = builtins.tryEval (
          systemd.mkTerranixActivation {
            serviceName = "test";
            instanceName = "unit";
            # Neither terraformConfigPath nor terranixModule provided
          }
        );

        # Test empty service names
        emptyServiceTest = builtins.tryEval (pure.makeServiceName "" "test");

        # Test terranix scripts with minimum valid input
        minimalScripts = systemd.mkTerranixScripts {
          serviceName = "s";
          instanceName = "i";
        };
      in
      {
        invalidActivationFails = !invalidActivationTest.success;
        emptyServiceWorks = emptyServiceTest.success;
        emptyServiceResult = if emptyServiceTest.success then emptyServiceTest.value else "";
        minimalScriptsCount = builtins.length minimalScripts;
        minimalScriptsWork = builtins.all (script: script ? name) minimalScripts;
      };
    expected = {
      invalidActivationFails = true;
      emptyServiceWorks = true;
      emptyServiceResult = "-test";
      minimalScriptsCount = 4;
      minimalScriptsWork = true;
    };
  };
}
