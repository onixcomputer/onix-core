_: {
  instances = {
    # Harmonia - Nix binary cache service
    "harmonia" = {
      module.name = "harmonia";
      module.input = "self";
      roles.server = {
        tags."nix-cache" = { };
        settings = {
          # Clan-specific options
          subdomain = null; # Set to "cache" if using tailscale-traefik
          enableNginx = false; # Set to true for basic nginx reverse proxy
          priority = 30; # Default cache priority (lower number = higher priority)
          generateSigningKey = true; # Auto-generate signing key for the cache

          # Harmonia-specific settings (passed through freeformType)
          settings = {
            # Bind to all interfaces on port 5000
            bind = "[::]:5000";

            # Number of worker threads
            workers = 4;

            # Maximum connections per worker
            max_connection_rate = 256;

            # Cache priority (can also be set via clan option above)
            priority = 30;

            # Optional: Enable built-in TLS (if not using reverse proxy)
            # tls_cert_path = "/path/to/cert.pem";
            # tls_key_path = "/path/to/key.pem";
          };

          # Optional: Use existing signing keys instead of generating new ones
          # signKeyPaths = [ "/path/to/existing/key.sec" ];

          # Optional: Additional environment variables
          # environment = {
          #   RUST_LOG = "info";
          # };
        };
      };
    };

    # Harmonia client configuration for desktop machines
    "harmonia-client" = {
      module.name = "harmonia";
      module.input = "self";
      roles.client = {
        tags."desktop" = { }; # Apply to machines with desktop tag
        settings = {
          serverUrl = "http://britton-fw:5000";
          priority = 30; # Default cache priority

          # The signing key is automatically pulled from the shared vars
          # Using default extra substituters:
          # - https://nix-community.cachix.org
          # - https://cache.nixos.org/
        };
      };
    };

    # Example: Secondary cache with different priority
    # "harmonia-secondary" = {
    #   module.name = "harmonia";
    #   module.input = "self";
    #   roles.server = {
    #     tags."nix-cache" = { };
    #     settings = {
    #       subdomain = "cache-secondary";
    #       priority = 50;  # Lower priority than primary
    #       generateSigningKey = true;
    #
    #       settings = {
    #         bind = "[::]:5001";  # Different port
    #       };
    #     };
    #   };
    # };
  };
}

# To use Harmonia with tailscale-traefik:
# 1. Configure tailscale-traefik for the same machine
# 2. Add harmonia to the tailscale-traefik services configuration:
#
# clan.services.tailscale-traefik.server = {
#   domain = "example.com";
#   email = "admin@example.com";
#   services = {
#     harmonia = {
#       subdomain = "cache";
#       port = 5000;
#     };
#   };
# };
