# Error Message Tests - Verify enhanced error guidance
# Tests that error messages provide helpful, actionable guidance for common mistakes
{
  lib ? import <nixpkgs/lib>,
  pkgs ? import <nixpkgs> { },
  opentofu ? (import ../../default.nix { inherit lib pkgs; }),
}:

{
  # Test credential mapping error messages
  test_credential_mapping_errors = {
    expr =
      let
        # Test null credential mapping
        nullTest = builtins.tryEval (opentofu.validateCredentialMapping null);
        # Test invalid type (string instead of attrset)
        invalidTypeTest = builtins.tryEval (opentofu.validateCredentialMapping "password");

        # Test suspicious credential mapping (same key/value)
        suspiciousTest = builtins.tryEval (opentofu.validateCredentialMapping { password = "password"; });

        # Test invalid entries (empty strings)
        invalidEntriesTest = builtins.tryEval (opentofu.validateCredentialMapping { "" = "valid_name"; });

        # Test valid empty mapping (should pass)
        validEmptyTest = builtins.tryEval (opentofu.validateCredentialMapping { });
        validEmptyPassed = validEmptyTest.success;

        # Test valid mapping (should pass)
        validMappingTest = builtins.tryEval (
          opentofu.validateCredentialMapping { admin_password = "postgres_admin_password"; }
        );
        validMappingPassed = validMappingTest.success;

      in
      {
        nullTestFails = !nullTest.success;
        invalidTypeTestFails = !invalidTypeTest.success;
        suspiciousTestFails = !suspiciousTest.success;
        invalidEntriesTestFails = !invalidEntriesTest.success;
        validEmptyPasses = validEmptyPassed;
        validMappingPasses = validMappingPassed;
        hasNullGuidance =
          if nullTest.success then
            false
          else
            lib.hasInfix "credentialMapping cannot be null" nullTest.value.message or "";
        hasTypeGuidance =
          if invalidTypeTest.success then
            false
          else
            lib.hasInfix "Expected attribute set" invalidTypeTest.value.message or "";
        hasSuspiciousGuidance =
          if suspiciousTest.success then
            false
          else
            lib.hasInfix "Suspicious credential mapping" suspiciousTest.value.message or "";
      };
    expected = {
      nullTestFails = true;
      invalidTypeTestFails = true;
      suspiciousTestFails = true;
      invalidEntriesTestFails = true;
      validEmptyPasses = true;
      validMappingPasses = true;
      hasNullGuidance = true;
      hasTypeGuidance = true;
      hasSuspiciousGuidance = true;
    };
  };

  # Test terranix configuration error messages
  test_terranix_config_errors = {
    expr =
      let
        # Test empty configuration
        emptyConfigTest = builtins.tryEval (opentofu.validateTerranixConfig { });

        # Test function not called (this is tricky to test directly, but we can test the detection)
        functionIssues = opentofu.detectCommonFailures builtins.isFunction;
        hasFunctionIssue = builtins.length functionIssues > 0;

        # Test empty resources block
        emptyResourcesConfig = {
          terraform.required_version = ">= 1.0";
          resource = { };
        };
        emptyResourcesIssues = opentofu.detectCommonFailures emptyResourcesConfig;
        hasEmptyResourcesIssue = builtins.any (issue: issue.type == "empty_resources") emptyResourcesIssues;

        # Test missing provider configuration
        missingProviderConfig = {
          resource.postgresql_database.test = {
            name = "test";
          };
          # Missing provider config
        };
        missingProviderIssues = opentofu.detectCommonFailures missingProviderConfig;
        hasMissingProviderIssue = builtins.any (
          issue: issue.type == "missing_provider"
        ) missingProviderIssues;

        # Test valid configuration (should pass)
        validConfig = {
          terraform.required_version = ">= 1.0";
          terraform.required_providers.null = {
            source = "hashicorp/null";
          };
          resource.null_resource.test = {
            triggers.message = "hello";
          };
        };
        validConfigTest = builtins.tryEval (opentofu.validateTerranixConfig validConfig);
        validConfigPasses = validConfigTest.success;

      in
      {
        emptyConfigFails = !emptyConfigTest.success;
        functionIssueDetected = hasFunctionIssue;
        emptyResourcesDetected = hasEmptyResourcesIssue;
        missingProviderDetected = hasMissingProviderIssue;
        inherit validConfigPasses;
        errorHasGuidance =
          if emptyConfigTest.success then
            false
          else
            lib.hasInfix "Troubleshooting Guide" emptyConfigTest.value.message or "";
      };
    expected = {
      emptyConfigFails = true;
      functionIssueDetected = true;
      emptyResourcesDetected = true;
      missingProviderDetected = true;
      validConfigPasses = true;
      errorHasGuidance = true;
    };
  };

  # Test backend configuration error messages
  test_backend_config_errors = {
    expr =
      let
        # Test unsupported backend type
        unsupportedBackendTest = builtins.tryEval (
          opentofu.mkBackend {
            backendType = "consul"; # Not supported yet
            serviceName = "test";
            instanceName = "unit";
          }
        );

        # Test valid local backend (should pass)
        validLocalTest = builtins.tryEval (
          opentofu.mkBackend {
            backendType = "local";
            serviceName = "test";
            instanceName = "unit";
          }
        );
        validLocalPasses = validLocalTest.success;

        # Test valid S3 backend (should pass)
        validS3Test = builtins.tryEval (
          opentofu.mkBackend {
            backendType = "s3";
            serviceName = "test";
            instanceName = "unit";
          }
        );
        validS3Passes = validS3Test.success;

      in
      {
        unsupportedBackendFails = !unsupportedBackendTest.success;
        inherit validLocalPasses;
        inherit validS3Passes;
        hasBackendTypeGuidance =
          if unsupportedBackendTest.success then
            false
          else
            lib.hasInfix "Backend type guide" unsupportedBackendTest.value.message or "";
        hasCommonFixes =
          if unsupportedBackendTest.success then
            false
          else
            lib.hasInfix "Common fixes:" unsupportedBackendTest.value.message or "";
      };
    expected = {
      unsupportedBackendFails = true;
      validLocalPasses = true;
      validS3Passes = true;
      hasBackendTypeGuidance = true;
      hasCommonFixes = true;
    };
  };

  # Test systemd service validation error messages
  test_systemd_service_errors = {
    expr =
      let
        # Test missing required fields
        incompleteConfigTest = builtins.tryEval (
          opentofu.validateCompleteServiceConfig {
            serviceName = "test";
            # Missing instanceName and credentialMapping
          }
        );

        # Test valid complete config (should pass)
        validConfigTest = builtins.tryEval (
          opentofu.validateCompleteServiceConfig {
            serviceName = "test";
            instanceName = "unit";
            credentialMapping = { };
          }
        );
        validConfigPasses = validConfigTest.success;

        # Test terranix infrastructure error (missing config source)
        missingConfigTest = builtins.tryEval (
          opentofu.mkTerranixInfrastructure {
            serviceName = "test";
            instanceName = "unit";
            credentialMapping = { };
            # Missing both terraformConfigPath and terranixModule
          }
        );

      in
      {
        incompleteConfigFails = !incompleteConfigTest.success;
        inherit validConfigPasses;
        missingConfigFails = !missingConfigTest.success;
        hasFieldGuidance =
          if incompleteConfigTest.success then
            false
          else
            lib.hasInfix "Field requirements:" incompleteConfigTest.value.message or "";
        hasWorkingExample =
          if incompleteConfigTest.success then
            false
          else
            lib.hasInfix "Complete working example:" incompleteConfigTest.value.message or "";
        hasConfigSourceGuidance =
          if missingConfigTest.success then
            false
          else
            lib.hasInfix "Terranix approach (recommended):" missingConfigTest.value.message or "";
      };
    expected = {
      incompleteConfigFails = true;
      validConfigPasses = true;
      missingConfigFails = true;
      hasFieldGuidance = true;
      hasWorkingExample = true;
      hasConfigSourceGuidance = true;
    };
  };

  # Test error message quality and completeness
  test_error_message_quality = {
    expr =
      let
        # Test that error messages include common elements
        sampleCredentialError = builtins.tryEval (opentofu.validateCredentialMapping null);
        credentialErrorMessage =
          if sampleCredentialError.success then "" else sampleCredentialError.value.message or "";

        sampleTerranixError = builtins.tryEval (opentofu.validateTerranixConfig { });
        terranixErrorMessage =
          if sampleTerranixError.success then "" else sampleTerranixError.value.message or "";

        sampleBackendError = builtins.tryEval (
          opentofu.mkBackend {
            backendType = "invalid";
            serviceName = "test";
            instanceName = "unit";
          }
        );
        backendErrorMessage =
          if sampleBackendError.success then "" else sampleBackendError.value.message or "";

      in
      {
        # Check that error messages have helpful elements
        credentialErrorHasExamples = lib.hasInfix "Examples:" credentialErrorMessage;
        credentialErrorHasQuickFixes = lib.hasInfix "Quick fixes:" credentialErrorMessage;
        credentialErrorExplainsWorkflow = lib.hasInfix "How it works:" credentialErrorMessage;

        terranixErrorHasTroubleshooting = lib.hasInfix "Troubleshooting Guide:" terranixErrorMessage;
        terranixErrorHasExamples = lib.hasInfix "WORKING EXAMPLES:" terranixErrorMessage;
        terranixErrorHasDebugging = lib.hasInfix "DEBUGGING STEPS:" terranixErrorMessage;

        backendErrorHasTypeGuide = lib.hasInfix "Backend type guide:" backendErrorMessage;
        backendErrorHasCommonFixes = lib.hasInfix "Common fixes:" backendErrorMessage;
        backendErrorHasRecommendations = lib.hasInfix "Need shared state?" backendErrorMessage;

        # Check error message structure
        errorsAreMultiLine =
          lib.hasInfix "\n" credentialErrorMessage
          && lib.hasInfix "\n" terranixErrorMessage
          && lib.hasInfix "\n" backendErrorMessage;

        errorsHaveEmojis =
          lib.hasInfix "❌" credentialErrorMessage && lib.hasInfix "✅" credentialErrorMessage;
      };
    expected = {
      credentialErrorHasExamples = true;
      credentialErrorHasQuickFixes = true;
      credentialErrorExplainsWorkflow = true;
      terranixErrorHasTroubleshooting = true;
      terranixErrorHasExamples = true;
      terranixErrorHasDebugging = true;
      backendErrorHasTypeGuide = true;
      backendErrorHasCommonFixes = true;
      backendErrorHasRecommendations = true;
      errorsAreMultiLine = true;
      errorsHaveEmojis = true;
    };
  };
}
