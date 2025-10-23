# Checks for onix-core infrastructure
# Testing for modules and libraries using tiered approach

{ ... }:
{
  perSystem =
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
                ${../modules/lib/opentofu/.}/test-pure.nix \
                --eval-store $(realpath .) \
                --show-trace \
                --extra-experimental-features flakes
              echo "Pure function tests completed successfully"
              touch $out
            '';

        # TIER 2: Integration tests via nix build (derivation-based functions)
        eval-opentofu-integration = import ../modules/lib/opentofu/test-integration.nix {
          inherit pkgs lib;
          self = self';
        };

        # TIER 3: Real Terraform execution tests (validates terranix configs work with actual terraform)
        opentofu-terraform-execution = import ../modules/lib/opentofu/terraform-execution-tests.nix {
          inherit pkgs lib;
        };

        # TIER 3: System integration test (commented out for now - expensive)
        # opentofu-system-test = import ../modules/lib/opentofu/test-system.nix {
        #   inherit pkgs lib;
        #   self = self';
        #   nixosLib = import (pkgs.path + "/nixos/lib") { };
        # };

        # Keycloak module evaluation test (basic check)
        eval-keycloak-module =
          pkgs.runCommand "keycloak-module-test"
            {
              nativeBuildInputs = [ pkgs.nix ];
            }
            ''
              cd ${toString ./..}
              echo "Testing keycloak module evaluation..."
              nix-instantiate --eval --strict -E '
                let
                  lib = import <nixpkgs/lib>;
                  keycloak = import ./modules/keycloak { inherit lib; };
                in
                  keycloak._class == "clan.service"
              ' > /dev/null
              echo "✓ Keycloak module evaluation: PASSED"
              touch $out
            '';
      };

      legacyPackages = {
        # Export OpenTofu test suites for different testing approaches
        opentofu-pure-tests = import ../modules/lib/opentofu/test-pure.nix {
          inherit (pkgs) lib;
        };

        opentofu-integration-tests = import ../modules/lib/opentofu/test-integration.nix {
          inherit pkgs lib;
          self = self';
        };

        # Real terraform execution tests
        opentofu-terraform-execution-tests = import ../modules/lib/opentofu/terraform-execution-tests.nix {
          inherit pkgs lib;
        };

        # Legacy test suite (for reference)
        opentofu-legacy-tests = import ../modules/lib/opentofu/test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Backward compatibility alias - restore original manual testing workflow
        opentofu-tests = import ../modules/lib/opentofu/test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };
      };
    };
}
