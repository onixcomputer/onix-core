{ lib, ... }:
let
  inherit (lib) mkDefault mkIf;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "radicle-nix-adapter";
    readme = ''
      Radicle CI adapter for Nix

      Provides integration between Radicle CI and Nix builds, enabling:
      - Automated Nix flake builds for Radicle repositories
      - Build result caching via Attic
      - HTML build reports
      - Integration with radicle-ci-broker

      Setup:
      1. Configure broker base URL for CI broker integration
      2. Set report base URL for build log access
      3. Configure Attic cache per repository for build caching
      4. Define trusted Nix settings for security

      The adapter monitors Radicle repositories and triggers Nix builds,
      pushing successful build artifacts to configured Attic caches.
    '';
  };

  roles = {
    server = {
      description = "Radicle CI Nix build adapter";
      interface = {
        # Freeform module - any attribute can be passed through to the underlying NixOS service
        freeformType = attrsOf anything;

        options = { };
      };

      perInstance =
        {
          extendSettings,
          ...
        }:
        {
          nixosModule =
            {
              pkgs,
              config,
              inputs,
              ...
            }:
            let
              localSettings = extendSettings {
                # Adapter name defaults to instance name
                name = mkDefault config.networking.hostName;

                # Optional broker base URL
                brokerBaseUrl = mkDefault null;

                # Report settings
                reportBaseUrl = mkDefault null;
                reportDir = mkDefault "/var/lib/radicle-ci/adapters/nix";

                # Cache configuration per repository
                cache = mkDefault { };

                # Trusted Nix settings
                trustedNixSettings = mkDefault { };

                # Enable by default
                enable = mkDefault true;
              };

              instanceName = localSettings.name;
            in
            {
              # Import the radicle-nix-adapter NixOS module
              imports = [ inputs.radicle-nix-adapter.nixosModules.default ];

              # Configure the radicle-nix-adapter instance
              services.radicle.ci.adapters.nix.instances.${instanceName} = {
                inherit (localSettings)
                  enable
                  name
                  reportDir
                  cache
                  trustedNixSettings
                  ;
                package =
                  mkDefault
                    pkgs.radicle-nix-adapter or inputs.radicle-nix-adapter.packages.${pkgs.system}.radicle-nix-adapter;
                brokerBaseUrl = mkIf (localSettings.brokerBaseUrl != null) localSettings.brokerBaseUrl;
                reportBaseUrl = mkIf (localSettings.reportBaseUrl != null) localSettings.reportBaseUrl;
              };
            };
        };
    };
  };

  # No perMachine configuration needed
  perMachine = _: {
    nixosModule = _: { };
  };
}
