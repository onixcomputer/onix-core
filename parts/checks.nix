# Checks for onix-core infrastructure
# Testing for modules and libraries using tiered approach
{
  pkgs,
  self',
  lib,
  ...
}:
{
  checks = {
    # TIER 1: Pure function tests via nix-unit (fast)
    eval-opentofu-pure =
      pkgs.runCommand "opentofu-pure-tests"
        {
          nativeBuildInputs = [ pkgs.nix-unit ];
        }
        ''
          export NIX_PATH=nixpkgs=${pkgs.path}
          echo "Running OpenTofu pure function tests..."
          ${pkgs.nix-unit}/bin/nix-unit \
            ${../lib/opentofu/.}/tests/unit/pure-test.nix \
            --eval-store $(realpath .) \
            --show-trace \
            --extra-experimental-features flakes
          echo "Pure function tests completed successfully"
          touch $out
        '';

    # TIER 2: Integration tests via nix build (derivation-based functions)
    eval-opentofu-integration = import ../lib/opentofu/test-integration.nix {
      inherit pkgs lib;
      self = self';
    };

    # TIER 3: Real Terraform execution tests (validates terranix configs work with actual terraform)
    opentofu-terraform-execution = import ../lib/opentofu/terraform-execution-tests.nix {
      inherit pkgs lib;
    };

    # TIER 3: Minimal system integration test (lightweight VM test)
    opentofu-system-minimal = import ../lib/opentofu/test-system-minimal.nix {
      inherit pkgs lib;
      self = self';
      nixosLib = import (pkgs.path + "/nixos/lib") { };
    };
  };

  legacyPackages = {
    # Export OpenTofu test suites for different testing approaches
    opentofu-pure-tests = import ../lib/opentofu/test-pure.nix {
      inherit (pkgs) lib;
    };

    opentofu-integration-tests = import ../lib/opentofu/test-integration.nix {
      inherit pkgs lib;
      self = self';
    };

    # Real terraform execution tests
    opentofu-terraform-execution-tests = import ../lib/opentofu/terraform-execution-tests.nix {
      inherit pkgs lib;
    };

    # Legacy test suite (for reference)
    opentofu-legacy-tests = import ../lib/opentofu/test.nix {
      inherit (pkgs) lib;
      inherit pkgs;
    };

    # Backward compatibility alias - restore original manual testing workflow
    opentofu-tests = import ../lib/opentofu/test.nix {
      inherit (pkgs) lib;
      inherit pkgs;
    };
  };
}
