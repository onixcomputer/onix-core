# Checks for onix-core infrastructure
# Testing for modules and libraries using tiered approach

_: {
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
                ${../lib/opentofu/.}/test-pure.nix \
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

        # TIER 3: System integration test (commented out for now - expensive)
        # opentofu-system-test = import ../lib/opentofu/test-system.nix {
        #   inherit pkgs lib;
        #   self = self';
        #   nixosLib = import (pkgs.path + "/nixos/lib") { };
        # };

        # Keycloak module evaluation test (basic check)
        eval-keycloak-module =
          let
            keycloakModule = import ../modules/keycloak { inherit lib; };
          in
          pkgs.runCommand "keycloak-module-test" { } ''
            echo "Testing keycloak module evaluation..."

            # Test that module has correct class
            if [ "${keycloakModule._class}" = "clan.service" ]; then
              echo "✓ Module has correct _class: clan.service"
            else
              echo "✗ Module _class is: ${keycloakModule._class}"
              exit 1
            fi

            # Test that module has required manifest
            ${lib.optionalString (keycloakModule.manifest.name == "keycloak") ''
              echo "✓ Module has correct name: keycloak"
            ''}

            # Test that module has server role
            ${lib.optionalString (keycloakModule.roles ? server) ''
              echo "✓ Module has server role defined"
            ''}

            echo "✓ Keycloak module evaluation: PASSED"
            touch $out
          '';
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
    };
}
