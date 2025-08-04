_: {
  instances = {
    # Traefik reverse proxy and load balancer
    "traefik" = {
      module.name = "traefik";
      module.input = "self";
      roles.proxy = {
        tags."proxy" = { };
        tags."loadbalancer" = { };
        settings = {
          # TLS/Certificate Management
          enableAutoTLS = true;
          # acmeEmail not needed for Tailscale certificates
          certificateResolver = "tailscale"; # Use Tailscale for certificates

          # Entry Points
          enableWebEntryPoint = true;
          enableWebSecureEntryPoint = true;
          autoRedirectToHTTPS = true;

          # Dashboard Configuration
          enableDashboard = true;
          dashboardHost = "traefik.bison-tailor.ts.net"; # Tailscale domain
          dashboardAuth = "none"; # Tailscale provides network-level auth

          # Service configurations - these are managed by Traefik only
          # Services with Traefik integration enabled will auto-register
          services = [
            # Example: External service with Tailscale auth
            # {
            #   name = "external-app";
            #   host = "app.bison-tailor.ts.net";
            #   backend = "http://192.168.1.100:8080";
            #   enableAuth = true;
            #   authType = "tailscale";
            #   tailscaleDomain = "bison-tailor.ts.net";
            #   middlewares = [ "rate-limit" ];
            # }
          ];

          # Default middleware
          defaultMiddlewares = [ "security-headers" ];

          # Advanced static configuration (optional)
          staticConfigOptions = {
            log = {
              level = "INFO";
              format = "json";
            };

            accessLog = {
              format = "json";
              fields = {
                headers = {
                  defaultMode = "drop";
                  names = {
                    User-Agent = "keep";
                  };
                };
              };
            };

            metrics = {
              prometheus = {
                addEntryPointsLabels = true;
                addServicesLabels = true;
              };
            };
          };

          # Advanced dynamic configuration (optional)
          dynamicConfigOptions = {
            # Custom middleware
            http.middlewares = {
              rate-limit = {
                rateLimit = {
                  average = 100;
                  burst = 200;
                };
              };

              compress = {
                compress = { };
              };
            };

            # Custom TLS options
            tls.options = {
              default = {
                minVersion = "VersionTLS12";
                cipherSuites = [
                  "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
                  "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
                  "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
                ];
              };
            };
          };
        };
      };
    };

    # Example: Additional Traefik instance with explicit service config
    # "traefik-services" = {
    #   module.name = "traefik";
    #   module.input = "self";
    #   roles.proxy = {
    #     tags."services-proxy" = { };
    #     settings = {
    #       # Use Tailscale for certificates
    #       enableAutoTLS = true;
    #       certificateResolver = "tailscale"; # No ACME email needed!
    #
    #       # Entry Points
    #       enableWebEntryPoint = true;
    #       enableWebSecureEntryPoint = true;
    #       autoRedirectToHTTPS = true;
    #
    #       # Dashboard
    #       enableDashboard = true;
    #       dashboardHost = "traefik-services.bison-tailor.ts.net";
    #       dashboardAuth = "none"; # Tailscale handles auth at network level
    #
    #       # Manual service configurations
    #       services = [
    #         {
    #           name = "internal-app";
    #           host = "app.bison-tailor.ts.net";
    #           backend = "http://localhost:3000";
    #           enableAuth = true;
    #           authType = "tailscale";
    #           tailscaleDomain = "bison-tailor.ts.net";
    #           middlewares = [ ];
    #         }
    #       ];
    #
    #       defaultMiddlewares = [ "security-headers" ];
    #     };
    #   };
    # };
  };
}
