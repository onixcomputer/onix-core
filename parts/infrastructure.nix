_: {
  flake = {
    lib = {
      # OpenTofu utilities
      opentofu = import ../lib/opentofu/default.nix;

      # OpenTofu testing utilities
      opentofuTesting = {
        pure = import ../lib/opentofu/test-pure.nix;
        integration = import ../lib/opentofu/test-integration.nix;
        system = import ../lib/opentofu/test-system.nix;
        executionTests = import ../lib/opentofu/terraform-execution-tests.nix;
        examples = {
          simple = import ../lib/opentofu/examples/simple-terranix-example.nix;
        };
      };

      # Terranix utilities
      terranix = import ../lib/opentofu/terranix.nix;

      # Terranix testing utilities
      terranixTesting = import ../lib/terranix-testing;
    };
  };
}
