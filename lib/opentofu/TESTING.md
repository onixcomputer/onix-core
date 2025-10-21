# OpenTofu Library Testing Strategy

This document describes the three-tier testing approach for the OpenTofu library, designed to provide comprehensive coverage while following clan-core best practices.

## Overview

The testing strategy separates concerns into three tiers:

1. **TIER 1: Pure Function Tests** - Fast, lightweight tests using nix-unit
2. **TIER 2: Integration Tests** - Derivation-based functionality testing
3. **TIER 3: System Tests** - End-to-end NixOS VM testing

This approach ensures appropriate testing tools for each level of functionality while maintaining fast feedback loops.

## TIER 1: Pure Function Tests

**Purpose**: Test pure Nix functions that don't create derivations or require complex imports.

**Framework**: nix-unit (fast, lightweight)

**File**: `test-pure.nix`

**What's tested**:
- Credential mapping generation (`generateLoadCredentials`)
- Terraform variables script generation (`generateTfvarsScript`)
- Basic configuration validation (`validateTerranixConfig`)
- Service name and path generation utilities
- Backend configuration templates
- Pure string manipulation and data transformation

**Running tests**:
```bash
# Direct execution
nix run nixpkgs#nix-unit -- lib/opentofu/test-pure.nix

# Via checks (faster in CI)
nix build .#checks.x86_64-linux.eval-opentofu-pure

# Via legacy packages
nix build .#legacyPackages.x86_64-linux.opentofu-pure-tests
```

**Example test structure**:
```nix
{
  test_credential_mapping = {
    expr =
      let
        mapping = { "db_pass" = "db_password"; };
        credentials = opentofu.generateLoadCredentials "test-service" mapping;
        sortedCredentials = builtins.sort (a: b: a < b) credentials;
      in {
        credentialCount = builtins.length credentials;
        firstCredential = builtins.head sortedCredentials;
      };
    expected = {
      credentialCount = 1;
      firstCredential = "db_pass:/run/secrets/vars/test-service/db_password";
    };
  };
}
```

## TIER 2: Integration Tests

**Purpose**: Test functions that create derivations or require complex imports.

**Framework**: nix build with custom test runner

**File**: `test-integration.nix`

**What's tested**:
- Helper script generation (`mkHelperScripts`)
- Activation script creation (`mkActivationScript`)
- Service generation (`mkDeploymentService`, `mkGarageInitService`)
- Terranix module evaluation (`evalTerranixModule`)
- Multi-service isolation and naming

**Running tests**:
```bash
# Via checks (recommended)
nix build .#checks.x86_64-linux.eval-opentofu-integration

# Via legacy packages
nix build .#legacyPackages.x86_64-linux.opentofu-integration-tests

# Direct execution
nix build -f lib/opentofu/test-integration.nix
```

**Test approach**:
- Uses `pkgs.runCommand` to create test derivation
- Verifies derivation properties and content
- Tests script generation and service creation
- Validates terranix module compilation

## TIER 3: System Tests

**Purpose**: End-to-end testing of complete deployment workflows.

**Framework**: NixOS VM tests (following clan patterns)

**File**: `test-system.nix`

**What's tested**:
- Complete keycloak + terraform deployment
- Service startup and dependency ordering
- Real terraform execution in test environment
- State management and idempotency
- Helper script functionality
- Error handling and recovery

**Running tests**:
```bash
# System tests are expensive and currently optional
# Uncomment in parts/checks.nix to enable in CI

# Direct execution (takes several minutes)
nix build -f lib/opentofu/test-system.nix
```

**Test environment**:
- Full NixOS VM with keycloak and PostgreSQL
- Real OpenTofu/Terraform execution
- Clan vars integration with secrets
- Service dependency verification

## Test Files Structure

```
lib/opentofu/
├── default.nix              # Full library with derivations
├── lib-pure.nix             # Pure functions only (no pkgs dependency)
├── test-pure.nix            # TIER 1: nix-unit tests
├── test-integration.nix     # TIER 2: derivation tests
├── test-system.nix          # TIER 3: NixOS VM tests
├── test.nix                 # Legacy test suite (for reference)
└── TESTING.md               # This documentation
```

## Writing New Tests

### Adding Pure Function Tests

1. Add function to `lib-pure.nix` if it doesn't require pkgs
2. Add test case to `test-pure.nix`:
   ```nix
   test_my_function = {
     expr = opentofu.myFunction "input";
     expected = "expected_output";
   };
   ```

### Adding Integration Tests

1. Add function to `default.nix` (full library)
2. Add test case to `test-integration.nix`:
   ```nix
   testMyDerivation = opentofu.mkMyFunction { ... };
   ```
3. Verify properties in the test runner script

### Adding System Tests

1. Extend `test-system.nix` with new test scenarios
2. Add service configurations to the test VM
3. Add verification steps to the test script

## CI Integration

The new testing structure integrates with clan-core's check patterns:

```nix
# parts/checks.nix
checks = {
  # Fast pure function tests (always run)
  eval-opentofu-pure = /* nix-unit runner */;

  # Integration tests (run on significant changes)
  eval-opentofu-integration = /* derivation tests */;

  # System tests (expensive, run periodically)
  # opentofu-system-test = /* NixOS VM tests */;
};
```

## Migration from Legacy Tests

The original `test.nix` had mixed concerns that caused nix-unit failures:

**Problems**:
- Mixed pure functions with derivation creation
- Used `builtins.isDerivation` (not available in nix-unit)
- Non-deterministic credential ordering in tests

**Solutions**:
- Separated pure functions into `lib-pure.nix`
- Fixed credential mapping tests with deterministic sorting
- Used appropriate testing frameworks for each tier

## Best Practices

1. **Use the right tier**: Pure functions → TIER 1, Derivations → TIER 2, Full system → TIER 3
2. **Keep tests deterministic**: Sort lists, use fixed inputs
3. **Test error conditions**: Use `builtins.tryEval` for expected failures
4. **Follow clan patterns**: Use similar structure to clan-core tests
5. **Fast feedback**: Run TIER 1 tests frequently, TIER 3 rarely

## Example Workflows

### Developer workflow:
```bash
# Quick feedback during development
nix run nixpkgs#nix-unit -- lib/opentofu/test-pure.nix

# Test integration when changing service generation
nix build .#checks.x86_64-linux.eval-opentofu-integration

# Full validation before PR
nix develop -c validate
```

### CI workflow:
```bash
# Always run (fast)
nix build .#checks.x86_64-linux.eval-opentofu-pure

# Run on library changes
nix build .#checks.x86_64-linux.eval-opentofu-integration

# Run system tests weekly or on major changes
# nix build .#checks.x86_64-linux.opentofu-system-test
```

This testing strategy provides comprehensive coverage while maintaining fast feedback and following established clan-core patterns.