# Flake module for OpenTofu library tests
# Following clan patterns from lib/values/flake-module.nix

_: {
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        # Unit tests for OpenTofu library functions
        eval-opentofu-library = pkgs.runCommand "tests" { nativeBuildInputs = [ pkgs.nix-unit ]; } ''
          export HOME="$(realpath .)"
          nix-unit --eval-store auto --flake .#legacyPackages.${pkgs.stdenv.hostPlatform.system}.opentofu-tests
          touch $out
        '';

        # Integration tests for OpenTofu library derivations
        opentofu-integration-tests = import ./test-integration.nix {
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
        # Export the test suite for nix-unit
        opentofu-tests = import ./test.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Export integration tests
        opentofu-integration-tests = import ./test-integration.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };

        # Export terraform execution tests
        opentofu-terraform-execution-tests = import ./terraform-execution-tests.nix {
          inherit (pkgs) lib;
          inherit pkgs;
        };
      };
    };
}
