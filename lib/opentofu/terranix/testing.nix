# Terranix Testing and Introspection Module
{ lib }:

let
  eval = import ./eval.nix { inherit lib; };
in
{
  # Testing utilities for terranix configurations
  testTerranixModule =
    {
      # Module to test
      module,
      # Test cases - attribute set of test scenarios
      testCases ? { },
      # Expected validation to pass
      shouldValidate ? true,
      # Expected structure checks
      expectedBlocks ? [ ],
    }:
    let
      # Run each test case
      testResults = lib.mapAttrs (
        testName: testArgs:
        let
          # Try to evaluate the module, catching errors
          testResult = builtins.tryEval (
            eval.evalTerranixModule {
              inherit module;
              moduleArgs = testArgs;
              validate = shouldValidate;
            }
          );

          # Check expected blocks if test succeeded
          blockChecks =
            if testResult.success && expectedBlocks != [ ] then
              lib.all (block: testResult.value ? ${block}) expectedBlocks
            else
              true;

        in
        {
          inherit (testResult) success;
          result = if testResult.success then testResult.value else null;
          error = if testResult.success then null else "Evaluation failed";
          inherit blockChecks;
          inherit testName;
        }
      ) testCases;

      # Collect test summary
      summary = {
        total = builtins.length (builtins.attrNames testResults);
        passed = builtins.length (
          lib.filter (test: test.success && test.blocksValid) (builtins.attrValues testResults)
        );
        failed = builtins.length (
          lib.filter (test: !test.success || !test.blocksValid) (builtins.attrValues testResults)
        );
      };

    in
    {
      inherit testResults summary;
      allPassed = summary.failed == 0;
    };

  # Debug and introspection utilities
  introspectTerranixModule =
    {
      # Module to introspect
      module,
      # Arguments for introspection
      moduleArgs ? { },
    }:
    let
      # Evaluate with debug mode
      evaluated = eval.evalTerranixModule {
        inherit module moduleArgs;
        debug = true;
        validate = false; # Don't validate during introspection
      };

      # Extract structure information
      structure = {
        hasProviders = evaluated ? provider;
        hasResources = evaluated ? resource;
        hasVariables = evaluated ? variable;
        hasOutputs = evaluated ? output;
        hasTerraform = evaluated ? terraform;

        # Count elements
        providerCount =
          if evaluated ? provider then builtins.length (builtins.attrNames evaluated.provider) else 0;
        resourceCount =
          if evaluated ? resource then
            builtins.length (
              lib.flatten (lib.mapAttrsToList (_: resources: builtins.attrNames resources) evaluated.resource)
            )
          else
            0;
        variableCount =
          if evaluated ? variable then builtins.length (builtins.attrNames evaluated.variable) else 0;
        outputCount =
          if evaluated ? output then builtins.length (builtins.attrNames evaluated.output) else 0;
      };

      # Extract provider information
      providers = lib.optionalAttrs (evaluated ? provider) {
        names = builtins.attrNames evaluated.provider;
        details = evaluated.provider;
      };

      # Extract resource types
      resourceTypes = lib.optionalAttrs (evaluated ? resource) (builtins.attrNames evaluated.resource);

      # Extract variables
      variables = lib.optionalAttrs (evaluated ? variable) (
        lib.mapAttrs (_: var: {
          type = var.type or "unknown";
          description = var.description or null;
          hasDefault = var ? default;
          sensitive = var.sensitive or false;
        }) evaluated.variable
      );

      # Extract outputs
      outputs = lib.optionalAttrs (evaluated ? output) (
        lib.mapAttrs (_: output: {
          description = output.description or null;
          sensitive = output.sensitive or false;
        }) evaluated.output
      );

    in
    {
      inherit
        structure
        providers
        resourceTypes
        variables
        outputs
        ;
      debugInfo = evaluated._debug or { };
      rawConfig = evaluated;
    };
}
