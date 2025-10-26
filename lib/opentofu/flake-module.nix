# Flake module for OpenTofu library tests
# Updated to use the new modular test structure
# Following clan patterns from lib/values/flake-module.nix

_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        # Unit tests for OpenTofu library functions (pure functions only)
        eval-opentofu-unit-tests =
          pkgs.runCommand "unit-tests"
            {
              nativeBuildInputs = [ pkgs.nix-unit ];
            }
            ''
              export HOME="$(realpath .)"
              nix-unit --eval-store auto --flake .#legacyPackages.${pkgs.stdenv.hostPlatform.system}.opentofu-unit-tests
              touch $out
            '';

        # Terranix pure function tests
        eval-terranix-pure-tests =
          pkgs.runCommand "terranix-pure-tests"
            {
              nativeBuildInputs = [ pkgs.nix-unit ];
            }
            ''
              export HOME="$(realpath .)"
              nix-unit --eval-store auto --flake .#legacyPackages.${pkgs.stdenv.hostPlatform.system}.terranix-pure-tests
              touch $out
            '';

        # Integration tests for OpenTofu library derivations
        opentofu-integration-tests = import ./tests/integration/integration-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Terraform execution tests that validate terranix-generated configs work with real terraform
        opentofu-terraform-execution-tests = import ./terraform-execution-tests.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };
      };

      legacyPackages = {
        # Export the new comprehensive unit test suite for nix-unit
        opentofu-unit-tests = import ./tests/unit/default.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Export individual unit test modules for granular testing
        terranix-pure-tests = import ./tests/unit/pure-test.nix {
          inherit (pkgs) lib;
        };

        opentofu-systemd-tests = import ./tests/unit/systemd-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        opentofu-terranix-tests = import ./tests/unit/terranix-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        opentofu-backends-tests = import ./tests/unit/backends-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        opentofu-error-message-tests = import ./tests/unit/error-messages-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Export integration tests
        opentofu-integration-tests = import ./tests/integration/integration-test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Export terraform execution tests
        opentofu-terraform-execution-tests = import ./terraform-execution-tests.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Main test suite export
        terranix-tests = import ./tests/unit/default.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };
      };
    };
}
