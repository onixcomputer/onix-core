# Shared library utilities for onix-core
# Provides common functions and helpers used across the flake
# Consolidates all lib exports (including former infrastructure.nix content)
{ inputs, ... }:
{
  flake.lib = {
    # Machine configuration helpers
    machines = {
      # Get all machine names from clan configuration
      names = builtins.attrNames (import ../inventory/core/machines.nix { });

      # Check if a machine has a specific tag
      hasTag =
        machine: tag:
        let
          machines = import ../inventory/core/machines.nix { };
        in
        builtins.elem tag (machines.${machine}.tags or [ ]);
    };

    # Tag utilities
    tags = {
      # Get all available tags
      all =
        let
          tagDir = ../inventory/tags;
          contents = builtins.readDir tagDir;
          nixFiles = builtins.filter (name: builtins.match ".*\\.nix" name != null && name != "default.nix") (
            builtins.attrNames contents
          );
        in
        map (name: builtins.replaceStrings [ ".nix" ] [ "" ] name) nixFiles;
    };

    # User/roster utilities
    roster = {
      # Get all user names from roster
      users =
        let
          roster = import ../inventory/core/roster.nix { };
        in
        builtins.attrNames roster;
    };

    # OpenTofu utilities (consolidated from infrastructure.nix)
    opentofu = import ../lib/opentofu/default.nix;

    # Terranix utilities
    terranix = import ../lib/opentofu/terranix.nix;

    # Testing utilities (consolidated from infrastructure.nix)
    opentofuTesting = {
      pure = import ../lib/opentofu/test-pure.nix;
      integration = import ../lib/opentofu/test-integration.nix;
      system = import ../lib/opentofu/test-system.nix;
      executionTests = import ../lib/opentofu/terraform-execution-tests.nix;
      examples = {
        simple = import ../lib/opentofu/examples/simple-terranix-example.nix;
      };
    };

    terranixTesting = import ../lib/terranix-testing;

    # Flake input passthrough for downstream use
    inherit inputs;
  };
}
