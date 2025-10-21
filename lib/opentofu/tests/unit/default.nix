# Terranix OpenTofu Library Unit Tests - Combined Test Suite
# Aggregates all unit test modules for nix-unit testing
#
# Usage:
#   nix-unit --eval-store auto --flake .#legacyPackages.x86_64-linux.opentofu-unit-tests
#
# This file combines tests from:
# - pure-test.nix: Tests for pure functions (lib-pure.nix)
# - systemd-test.nix: Tests for terranix-focused systemd integration modules
# - terranix-test.nix: Tests for terranix evaluation and generation
# - backends-test.nix: Tests for backend configuration modules
{
  lib ? import <nixpkgs/lib>,
  pkgs ? import <nixpkgs> { },
}:

let
  # Import all unit test modules
  pureTests = import ./pure-test.nix { inherit lib; };
  systemdTests = import ./systemd-test.nix { inherit lib pkgs; };
  terranixTests = import ./terranix-test.nix { inherit lib pkgs; };
  backendsTests = import ./backends-test.nix { inherit lib pkgs; };
  errorMessageTests = import ./error-messages-test.nix { inherit lib pkgs; };

  # Helper function to prefix test names to avoid conflicts
  prefixTests =
    prefix: tests:
    lib.mapAttrs' (name: value: {
      name = "${prefix}_${name}";
      inherit value;
    }) tests;

in
# Combine all tests with prefixed names for clear identification
(prefixTests "pure" pureTests)
// (prefixTests "systemd" systemdTests)
// (prefixTests "terranix" terranixTests)
// (prefixTests "backends" backendsTests)
// (prefixTests "errors" errorMessageTests)
// {
  # Meta-test to verify the test structure itself
  test_meta_test_count = {
    expr =
      let
        allTests =
          (prefixTests "pure" pureTests)
          // (prefixTests "systemd" systemdTests)
          // (prefixTests "terranix" terranixTests)
          // (prefixTests "backends" backendsTests)
          // (prefixTests "errors" errorMessageTests);
        testCount = builtins.length (builtins.attrNames allTests);

        # Count tests by category
        pureTestCount = builtins.length (builtins.attrNames pureTests);
        systemdTestCount = builtins.length (builtins.attrNames systemdTests);
        terranixTestCount = builtins.length (builtins.attrNames terranixTests);
        backendsTestCount = builtins.length (builtins.attrNames backendsTests);
        errorMessageTestCount = builtins.length (builtins.attrNames errorMessageTests);
      in
      {
        totalTests = testCount;
        pureTests = pureTestCount;
        systemdTests = systemdTestCount;
        terranixTests = terranixTestCount;
        backendsTests = backendsTestCount;
        errorMessageTests = errorMessageTestCount;
        hasAllCategories =
          pureTestCount > 0
          && systemdTestCount > 0
          && terranixTestCount > 0
          && backendsTestCount > 0
          && errorMessageTestCount > 0;
      };
    expected = {
      # These values will vary as tests are added/removed
      totalTests = 46; # Updated for new error message tests
      pureTests = 12;
      systemdTests = 10;
      terranixTests = 10;
      backendsTests = 10;
      errorMessageTests = 4;
      hasAllCategories = true;
    };
  };

  # Test that verifies the test naming convention
  test_meta_naming_convention = {
    expr =
      let
        allTests =
          (prefixTests "pure" pureTests)
          // (prefixTests "systemd" systemdTests)
          // (prefixTests "terranix" terranixTests)
          // (prefixTests "backends" backendsTests);
        testNames = builtins.attrNames allTests;

        # Check that all test names follow the expected patterns
        pureTestNames = builtins.filter (name: lib.hasPrefix "pure_" name) testNames;
        systemdTestNames = builtins.filter (name: lib.hasPrefix "systemd_" name) testNames;
        terranixTestNames = builtins.filter (name: lib.hasPrefix "terranix_" name) testNames;
        backendsTestNames = builtins.filter (name: lib.hasPrefix "backends_" name) testNames;

        # Verify all names start with test_
        allHaveTestPrefix = builtins.all (name: lib.hasInfix "_test_" name) testNames;
      in
      {
        pureTestsNamed = builtins.length pureTestNames;
        systemdTestsNamed = builtins.length systemdTestNames;
        terranixTestsNamed = builtins.length terranixTestNames;
        backendsTestsNamed = builtins.length backendsTestNames;
        allHaveCorrectPrefix = allHaveTestPrefix;
        totalNamedTests = builtins.length testNames;
      };
    expected = {
      pureTestsNamed = 12;
      systemdTestsNamed = 10;
      terranixTestsNamed = 10;
      backendsTestsNamed = 10;
      allHaveCorrectPrefix = true;
      totalNamedTests = 42;
    };
  };

  # Integration meta-test that verifies cross-module consistency
  test_meta_cross_module_consistency = {
    expr =
      let
        # Test that functions exist across modules as expected
        hasServiceNameGeneration =
          (pureTests ? test_service_name_generation) && (systemdTests ? test_helper_script_names);

        hasBackendConfiguration =
          (pureTests ? test_backend_configs) && (backendsTests ? test_local_backend_config);

        hasTerranixValidation =
          (pureTests ? test_terranix_validation) && (terranixTests ? test_terranix_validation);

        hasHealthCheckSystem = systemdTests ? test_health_check_strategies;
      in
      {
        crossModuleServiceNames = hasServiceNameGeneration;
        crossModuleBackends = hasBackendConfiguration;
        crossModuleTerranix = hasTerranixValidation;
        crossModuleHealthChecks = hasHealthCheckSystem;
        allCrossModuleTestsExist =
          hasServiceNameGeneration
          && hasBackendConfiguration
          && hasTerranixValidation
          && hasHealthCheckSystem;
      };
    expected = {
      crossModuleServiceNames = true;
      crossModuleBackends = true;
      crossModuleTerranix = true;
      crossModuleHealthChecks = true;
      allCrossModuleTestsExist = true;
    };
  };
}
