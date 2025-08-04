{ lib }:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    optional
    ;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    enum
    ;
in
rec {
  # Standard Traefik integration options for any service
  mkTraefikOptions = {
    enable = mkOption {
      type = bool;
      default = true;
      description = "Enable automatic Traefik integration if available";
    };

    host = mkOption {
      type = nullOr str;
      default = null;
      description = "Hostname for Traefik routing (e.g., service.example.com)";
    };

    enableAuth = mkOption {
      type = bool;
      default = false;
      description = "Enable authentication through Traefik";
    };

    authType = mkOption {
      type = enum [
        "basic"
        "tailscale"
      ];
      default = "basic";
      description = "Type of authentication to use (basic or tailscale)";
    };

    tailscaleDomain = mkOption {
      type = nullOr str;
      default = null;
      description = "Tailscale domain for authentication (e.g., your-company.ts.net)";
    };

    middlewares = mkOption {
      type = listOf str;
      default = [ ];
      description = "Additional Traefik middlewares to apply";
    };
  };

  # Create Traefik integration configuration for a service
  mkTraefikIntegration =
    {
      serviceName,
      servicePort,
      traefikConfig,
      config,
      extraMiddlewares ? [ ],
      extraRouterConfig ? { },
      extraServiceConfig ? { },
    }:
    let
      hasTraefik =
        (config.services.traefik.enable or false)
        && (traefikConfig.enable or true)
        && (traefikConfig.host or null) != null;

      authMiddleware =
        if (traefikConfig.enableAuth or false) then
          if (traefikConfig.authType or "basic") == "tailscale" then
            "${serviceName}-tailscale-auth"
          else
            "${serviceName}-auth"
        else
          null;

      allMiddlewares = [
        "security-headers"
      ]
      ++ (traefikConfig.middlewares or [ ])
      ++ extraMiddlewares
      ++ optional (authMiddleware != null) authMiddleware;
    in
    mkIf hasTraefik {
      dynamicConfigOptions.http = {
        routers.${serviceName} = mkMerge [
          {
            rule = "Host(`${traefikConfig.host}`)";
            service = serviceName;
            entryPoints = [ "websecure" ];
            middlewares = allMiddlewares;
            tls.certResolver = "letsencrypt";
          }
          extraRouterConfig
        ];

        services.${serviceName} = mkMerge [
          {
            loadBalancer.servers = [
              { url = "http://localhost:${toString servicePort}"; }
            ];
          }
          extraServiceConfig
        ];

        middlewares = mkMerge [
          # Basic auth middleware
          (mkIf ((traefikConfig.enableAuth or false) && (traefikConfig.authType or "basic") == "basic") {
            "${serviceName}-auth" = {
              basicAuth.usersFile =
                config.clan.core.vars.generators."${serviceName}-traefik-auth".files.htpasswd.path;
            };
          })

          # Tailscale auth middleware
          (mkIf ((traefikConfig.enableAuth or false) && (traefikConfig.authType or "basic") == "tailscale") {
            "${serviceName}-tailscale-auth" = {
              plugin.tailscale-connectivity = {
                testDomain = traefikConfig.tailscaleDomain or config.networking.domain or "example.ts.net";
                sessionTimeout = "24h";
                allowLocalhost = false;
              };
            };
          })
        ];
      };
    };

  # Create vars generator for Traefik auth
  mkTraefikAuthGenerator =
    { serviceName, pkgs }:
    {
      "${serviceName}-traefik-auth" = {
        files.htpasswd = {
          owner = "traefik";
          group = "traefik";
          mode = "0400";
        };
        runtimeInputs = with pkgs; [ apacheHttpd ];
        prompts."${serviceName}_traefik_password" = {
          description = "Password for ${serviceName} Traefik authentication";
          type = "hidden";
          persist = true;
        };
        script = ''
          htpasswd -nbB ${serviceName} "$prompts/${serviceName}_traefik_password" > "$out/htpasswd"
        '';
      };
    };

  # Check if Traefik auth is needed for a service
  needsTraefikAuth =
    { serviceName, config }:
    let
      serviceConfig = config.nodes.${config.networking.hostName}.services.${serviceName} or { };
      # Handle different role names (server, proxy, etc.)
      roleConfig = serviceConfig.server or serviceConfig.client or serviceConfig.proxy or { };
    in
    (roleConfig.traefik.enable or true)
    && (roleConfig.traefik.enableAuth or false)
    && (roleConfig.traefik.authType or "basic") == "basic"
    && (config.services.traefik.enable or false);
}
