_: {
  instances = {
    radicle-nix-adapter = {
      module.name = "radicle-nix-adapter";
      module.input = "self";

      roles.server = {
        # Deploy to machines with radicle-ci tag
        tags."radicle-ci" = { };

        settings = {
          # Adapter configuration
          # These are default values - override in machine-specific config as needed

          # Base URL for the CI broker (optional)
          # brokerBaseUrl = "https://radicle-ci.example.com";

          # Base URL for build reports (required for web access)
          # reportBaseUrl = "https://radicle-ci.example.com/reports";

          # Directory for HTML build reports
          reportDir = "/var/lib/radicle-ci/adapters/nix";

          # Cache configuration per repository
          # Example:
          # cache = {
          #   "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5" = {
          #     attic = {
          #       server = "https://attic.example.com";
          #       cache = "radicle-nix-ci";
          #       tokenFile = "/run/secrets/attic-token";
          #     };
          #   };
          # };
          cache = { };

          # Trusted Nix settings
          # Controls which nixConfig values to trust in flake.nix
          # Example:
          # trustedNixSettings = {
          #   abort-on-warn = {
          #     true = true;
          #   };
          # };
          trustedNixSettings = { };

          # Enable the adapter
          enable = true;
        };
      };
    };
  };
}
