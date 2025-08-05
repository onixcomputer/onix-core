# Security ACME service configuration
# This service manages ACME certificates for the infrastructure
# Currently configured to work alongside tailscale-traefik

_: {
  instances = {
    "acme-certs" = {
      module.name = "security-acme";
      module.input = "self";

      # Certificate provider - generates certificates on britton-fw
      roles.provider = {
        # Deploy specifically on britton-fw (which has traefik-homepage tag)
        machines."britton-fw" = { };

        settings = {
          # Update this with your actual email address for Let's Encrypt
          email = "admin@onix.computer"; # TODO: Replace with your real email
          acceptTerms = true; # You must accept Let's Encrypt's terms of service

          # Generate and share a wildcard certificate
          shareWildcard = true;
          wildcardDomain = "onix.computer"; # Will be configured as wildcard in the module

          # Use Cloudflare for DNS challenges
          dnsProvider = "cloudflare";
          # The module will automatically use security-acme-dns credentials

          # Check for renewal twice daily
          renewalCheckInterval = "*-*-* 00,12:00:00";

          # Additional certificates to share if needed
          certificatesToShare = [
            # Add specific certificates here if needed
            # "api.onix.computer"
          ];

          # Advanced ACME configuration (freeform)
          defaults = {
            # Use elliptic curve keys for better performance
            keyType = "ec256";
            # Renew 30 days before expiry (default)
            # daysBeforeExpiry = 30;

            # Extra lego flags to help with DNS propagation
            extraLegoFlags = [
              # Don't disable propagation check - let it verify properly
              # "--dns.disable-cp"
              "--dns.resolvers=1.1.1.1:53" # Use Cloudflare DNS resolver
              "--dns-timeout=600" # Increase DNS timeout to 10 minutes
              "--dns.propagation-wait=300s" # Wait 5 minutes for propagation
              # NOTE: Do not use -v flag - it causes lego to only print version and exit!
            ];
          };

          # Configure specific certificates if needed
          # certs."api.onix.computer" = {
          #   extraDomainNames = [ "api-v2.onix.computer" ];
          #   keyType = "ec384";  # Stronger key for API
          # };
        };
      };

      # Certificate consumer - for machines that need certificates
      # Uncomment and configure when you have machines that need to consume certificates
      # roles.consumer = {
      #   # Machines that need the wildcard certificate
      #   tags."web-server" = { };
      #
      #   settings = {
      #     certificates = {
      #       # Wildcard certificate for general use
      #       wildcard = {
      #         domain = "onix.computer";  # The cert includes *.onix.computer
      #         # Set appropriate group for your services
      #         # group = "nginx";  # For nginx
      #         # group = "traefik";  # For traefik
      #         # reloadServices = [ "nginx.service" ];
      #       };
      #
      #       # Add more certificates as needed
      #       # api = {
      #       #   domain = "api.onix.computer";
      #       #   group = "api-service";
      #       #   reloadServices = [ "api.service" ];
      #       # };
      #     };
      #   };
      # };

      # Example: Integration with existing tailscale-traefik
      # To migrate from Traefik's built-in ACME to this service:
      #
      # 1. Deploy this service on the same machines as traefik
      # 2. Once certificates are generated, update tailscale-traefik config:
      #    - Disable ACME resolver
      #    - Configure file provider to use certificates from this service
      #
      # roles.consumer = {
      #   tags."traefik-homepage" = { };
      #   settings = {
      #     certificates = {
      #       traefik-wildcard = {
      #         domain = "*.onix.computer";
      #         group = "traefik";
      #         reloadServices = [ "traefik.service" ];
      #       };
      #     };
      #   };
      # };
    };
  };
}
