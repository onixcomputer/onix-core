{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    str
    bool
    int
    port
    listOf
    attrsOf
    submodule
    anything
    nullOr
    ;
in
{
  _class = "clan.service";
  manifest.name = "tailscale-traefik";

  roles = {
    server = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          domain = mkOption {
            type = str;
            description = "Base domain for all services (e.g., onix.computer)";
            example = "onix.computer";
          };

          email = mkOption {
            type = str;
            description = "Email address for Let's Encrypt certificates";
            example = "admin@example.com";
          };

          services = mkOption {
            type = attrsOf (submodule {
              options = {
                port = mkOption {
                  type = nullOr port;
                  default = null;
                  description = "Port where the service listens on localhost. Can be auto-detected for many services.";
                  example = 3000;
                };

                portPath = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "NixOS config path to the service port (e.g., 'services.myservice.port'). Used for automatic port detection.";
                  example = "services.myservice.settings.port";
                };

                subdomain = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Custom subdomain (defaults to service name)";
                  example = "custom-name";
                };

                extraRouterConfig = mkOption {
                  type = attrsOf anything;
                  default = { };
                  description = "Additional Traefik router configuration";
                };

                extraServiceConfig = mkOption {
                  type = attrsOf anything;
                  default = { };
                  description = "Additional Traefik service configuration";
                };

                middlewares = mkOption {
                  type = listOf str;
                  default = [ ];
                  description = "List of Traefik middlewares to apply";
                  example = [ "security-headers" ];
                };
              };
            });
            default = { };
            description = "Services to expose via Traefik";
            example = {
              grafana = {
                port = 3000;
              };
              vaultwarden = {
                port = 8080;
              };
            };
          };

          additionalSubdomains = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional subdomains to manage DNS for (without services)";
            example = [
              "api"
              "cdn"
            ];
          };

          traefikDashboard = mkOption {
            type = bool;
            default = true;
            description = "Enable Traefik dashboard on traefik.domain";
          };

          sslRedirect = mkOption {
            type = bool;
            default = true;
            description = "Redirect all HTTP traffic to HTTPS";
          };

          ddclientInterval = mkOption {
            type = int;
            default = 300;
            description = "Interval in seconds for ddclient to check/update DNS";
          };

          dnsPropagationCheck = mkOption {
            type = bool;
            default = true;
            description = "Whether to check DNS propagation before validation (disable if having issues)";
          };

          dnsResolvers = mkOption {
            type = listOf str;
            default = [
              "1.1.1.1:53"
              "1.0.0.1:53"
            ];
            description = "DNS resolvers for ACME challenge verification";
            example = [
              "8.8.8.8:53"
              "8.8.4.4:53"
            ];
          };

          dnsPropagationDelay = mkOption {
            type = int;
            default = 300;
            description = "Seconds to wait for DNS propagation before ACME validation";
          };

          extraTraefikConfig = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Additional Traefik static configuration to merge";
          };

          extraDynamicConfig = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Additional Traefik dynamic configuration to merge";
          };

          securityHeaders = mkOption {
            type = bool;
            default = true;
            description = "Enable security headers middleware";
          };

          tailscaleAuthKeyFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to Tailscale auth key file (uses clan vars by default)";
          };

          tailscaleExitNode = mkOption {
            type = bool;
            default = false;
            description = "Advertise this machine as a Tailscale exit node";
          };

          tailscaleSSH = mkOption {
            type = bool;
            default = false;
            description = "Enable SSH access via Tailscale";
          };

          tailscalePort = mkOption {
            type = port;
            default = 41641;
            description = "UDP port for Tailscale";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              cfg = extendSettings { };

              # Extract clan-specific options
              inherit (cfg) domain email;
              services = cfg.services or { };
              additionalSubdomains = cfg.additionalSubdomains or [ ];
              traefikDashboard = cfg.traefikDashboard or true;
              sslRedirect = cfg.sslRedirect or true;
              ddclientInterval = cfg.ddclientInterval or 300;
              extraTraefikConfig = cfg.extraTraefikConfig or { };
              extraDynamicConfig = cfg.extraDynamicConfig or { };
              securityHeaders = cfg.securityHeaders or true;
              dnsPropagationCheck = cfg.dnsPropagationCheck or false;
              dnsResolvers =
                cfg.dnsResolvers or [
                  "1.1.1.1:53"
                  "1.0.0.1:53"
                ];
              dnsPropagationDelay = cfg.dnsPropagationDelay or 120;
              tailscaleAuthKeyFile =
                cfg.tailscaleAuthKeyFile
                  or config.clan.core.vars.generators.tailscale-traefik.files.tailscale_auth_key.path;
              tailscaleExitNode = cfg.tailscaleExitNode or false;
              tailscaleSSH = cfg.tailscaleSSH or false;
              tailscalePort = cfg.tailscalePort or 41641;

              # Build list of all subdomains
              serviceSubdomains = lib.mapAttrsToList (
                name: svc: if svc.subdomain != null then svc.subdomain else name
              ) services;

              allSubdomains =
                serviceSubdomains ++ additionalSubdomains ++ (lib.optional traefikDashboard "traefik");

              # Script to get Tailscale IP
              getTailscaleIP = pkgs.writeShellScript "get-tailscale-ip" ''
                ${pkgs.tailscale}/bin/tailscale ip -4 | head -n1
              '';

              # Generate Traefik routes
              serviceRouters = lib.mapAttrs' (
                name: svc:
                let
                  inherit name;
                  subdomain = if svc.subdomain != null then svc.subdomain else name;
                in
                lib.nameValuePair subdomain (
                  {
                    rule = "Host(`${subdomain}.${domain}`)";
                    service = subdomain;
                    entryPoints = [ "websecure" ];
                    tls.certResolver = "letsencrypt";
                  }
                  // (lib.optionalAttrs (svc.middlewares != [ ]) {
                    inherit (svc) middlewares;
                  })
                  // (svc.extraRouterConfig or { })
                )
              ) services;

              # Generate Traefik services
              serviceBackends = lib.mapAttrs' (
                name: svc:
                let
                  inherit name;
                  subdomain = if svc.subdomain != null then svc.subdomain else name;
                  # Service port detection mapping
                  # Maps service names to functions that extract their ports from NixOS config
                  portDetectors = {
                    homepage = cfg: cfg.services.homepage-dashboard.listenPort or null;
                    grafana = cfg: cfg.services.grafana.settings.server.http_port or cfg.services.grafana.port or null;
                    vaultwarden = cfg: cfg.services.vaultwarden.config.rocketPort or null;
                    prometheus = cfg: cfg.services.prometheus.port or null;
                    loki = cfg: cfg.services.loki.configuration.server.http_listen_port or null;
                    gitea = cfg: cfg.services.gitea.settings.server.HTTP_PORT or null;
                    nextcloud = _cfg: 80; # Usually behind nginx
                    jellyfin = cfg: cfg.services.jellyfin.port or 8096;
                    # Add more services as needed
                  };

                  # Helper to get value from config path
                  getConfigValue =
                    path: cfg:
                    let
                      parts = lib.splitString "." path;
                      getValue =
                        obj: pathParts:
                        if pathParts == [ ] then
                          obj
                        else if obj ? ${lib.head pathParts} then
                          getValue obj.${lib.head pathParts} (lib.tail pathParts)
                        else
                          null;
                    in
                    getValue cfg parts;

                  # Try to detect port automatically
                  detectedPort =
                    # First, check if portPath is specified
                    if svc.portPath != null then
                      getConfigValue svc.portPath config
                    # Otherwise, use built-in detectors
                    else if portDetectors ? ${name} then
                      let
                        detector = portDetectors.${name};
                        result = detector config;
                      in
                      if result != null then result else null
                    else
                      null;

                  # Determine final port
                  actualPort =
                    if svc.port != null then
                      svc.port
                    else if detectedPort != null then
                      detectedPort
                    else
                      throw "Cannot determine port for service '${name}'. Please specify the 'port' option or add a port detector.";
                in
                lib.nameValuePair subdomain (
                  {
                    loadBalancer.servers = [
                      {
                        url = "http://localhost:${toString actualPort}";
                      }
                    ];
                  }
                  // (svc.extraServiceConfig or { })
                )
              ) services;

              # Traefik dashboard router
              dashboardRouter = lib.optionalAttrs traefikDashboard {
                traefik-dashboard = {
                  rule = "Host(`traefik.${domain}`)";
                  service = "api@internal";
                  entryPoints = [ "websecure" ];
                  tls.certResolver = "letsencrypt";
                };
              };

              # Security headers middleware
              securityMiddleware = lib.optionalAttrs securityHeaders {
                security-headers = {
                  headers = {
                    customRequestHeaders = {
                      X-Forwarded-Proto = "https";
                    };
                    customResponseHeaders = {
                      X-Frame-Options = "SAMEORIGIN";
                      X-Content-Type-Options = "nosniff";
                      Strict-Transport-Security = "max-age=31536000; includeSubDomains";
                    };
                  };
                };
              };

              # Paths for secret files
              cloudflareTokenFile =
                config.clan.core.vars.generators.tailscale-traefik.files.cloudflare_token.path;
              traefikEnvFile = config.clan.core.vars.generators.tailscale-traefik.files.traefik_env.path;

            in
            {
              # All services configuration
              services = {
                # Tailscale configuration
                tailscale = {
                  enable = true;
                  useRoutingFeatures = "both";
                  authKeyFile = tailscaleAuthKeyFile;
                  extraUpFlags =
                    (lib.optional tailscaleSSH "--ssh") ++ (lib.optional tailscaleExitNode "--advertise-exit-node");
                };

                # DDClient configuration for DNS updates
                ddclient = {
                  enable = true;
                  protocol = "cloudflare";
                  username = "token"; # For Cloudflare API token auth
                  passwordFile = cloudflareTokenFile;
                  zone = domain;
                  domains = map (subdomain: "${subdomain}.${domain}") allSubdomains;
                  use = "cmd, cmd='${getTailscaleIP}'";
                  verbose = true;
                  interval = "${toString ddclientInterval}s";
                };

                # Traefik configuration
                traefik = {
                  enable = true;

                  staticConfigOptions = mkMerge [
                    {
                      entryPoints = {
                        web = {
                          address = ":80";
                          http = lib.optionalAttrs sslRedirect {
                            redirections.entrypoint = {
                              to = "websecure";
                              scheme = "https";
                            };
                          };
                        };
                        websecure = {
                          address = ":443";
                        };
                      };

                      certificatesResolvers = {
                        letsencrypt = {
                          acme = {
                            inherit email;
                            storage = "/var/lib/traefik/acme.json";
                            dnsChallenge = {
                              provider = "cloudflare";
                              delayBeforeCheck = dnsPropagationDelay;
                              resolvers = dnsResolvers;
                            }
                            // (lib.optionalAttrs (!dnsPropagationCheck) {
                              # Disable propagation checks if having issues
                              disablePropagationCheck = true;
                            });
                          };
                        };
                      };

                      api = {
                        dashboard = traefikDashboard;
                        insecure = false;
                      };

                      log = {
                        level = "DEBUG";
                      };

                      accessLog = { };
                    }
                    extraTraefikConfig
                  ];

                  dynamicConfigOptions = mkMerge [
                    {
                      http = {
                        routers = serviceRouters // dashboardRouter;
                        services = serviceBackends;
                        middlewares = securityMiddleware;
                      };
                    }
                    extraDynamicConfig
                  ];

                  environmentFiles = [ traefikEnvFile ];
                };
              };

              # Firewall configuration - ONLY on Tailscale interface
              networking.firewall = {
                enable = mkDefault true;

                interfaces = {
                  tailscale0 = {
                    allowedTCPPorts = [
                      80
                      443
                    ];
                  };
                };

                checkReversePath = "loose";
                trustedInterfaces = [ "tailscale0" ];
                allowedUDPPorts = [ tailscalePort ];
              };

              # NAT configuration for exit nodes
              networking.nat = mkIf tailscaleExitNode {
                enable = true;
                externalInterface = mkDefault (mkIf (config.networking.interfaces ? "eth0") "eth0");
                internalInterfaces = [ "tailscale0" ];
              };

              # Service dependencies
              systemd.services.ddclient = {
                after = [ "tailscale.service" ];
                wants = [ "tailscale.service" ];

                preStart = ''
                  echo "Waiting for Tailscale to be ready..."
                  for i in {1..30}; do
                    if ${getTailscaleIP} >/dev/null 2>&1; then
                      echo "Tailscale IP available: $(${getTailscaleIP})"
                      break
                    fi
                    echo "Attempt $i/30..."
                    sleep 2
                  done
                '';
              };

              systemd.services.traefik = {
                after = [ "tailscale.service" ];
                wants = [ "tailscale.service" ];

                # Override DNS for ACME challenges to bypass systemd-resolved issues
                environment = {
                  # Force Go to use our DNS servers instead of system resolver
                  GODEBUG = "netdns=go";
                  # Custom resolver config for Go
                  RESOLV_CONF_PATH = "/run/traefik/resolv.conf";
                };

                preStart = ''
                  # Create a custom resolv.conf for Traefik with working DNS servers
                  mkdir -p /run/traefik
                  cat > /run/traefik/resolv.conf <<EOF
                  nameserver 1.1.1.1
                  nameserver 1.0.0.1
                  EOF
                '';
              };

              # Ensure required packages
              environment.systemPackages = with pkgs; [
                tailscale
                curl
                dig
              ];
            };
        };
    };
  };

  # Common configuration for all machines
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Create vars generators for all required secrets
        clan.core.vars.generators.tailscale-traefik = {
          files = {
            cloudflare_token = {
              mode = "0600";
            };
            traefik_env = {
              mode = "0600";
            };
            tailscale_auth_key = {
              mode = "0600";
            };
          };

          runtimeInputs = [ pkgs.coreutils ];

          prompts = {
            cloudflare_token = {
              description = "Cloudflare API token (needs Zone:Zone:Read and Zone:DNS:Edit permissions)";
              type = "hidden";
              persist = true;
            };
            cloudflare_email = {
              description = "Cloudflare account email";
              type = "line";
              persist = true;
            };
            tailscale_auth_key = {
              description = "Tailscale auth key";
              type = "hidden";
              persist = true;
            };
          };

          script = ''
            # Write individual secret files
            cat "$prompts"/cloudflare_token > "$out"/cloudflare_token
            cat "$prompts"/tailscale_auth_key > "$out"/tailscale_auth_key

            # Create Traefik environment file using the same token
            cat > "$out"/traefik_env <<EOF
            CF_API_EMAIL=$(cat "$prompts"/cloudflare_email)
            CF_DNS_API_TOKEN=$(cat "$prompts"/cloudflare_token)
            EOF
          '';
        };
      };
  };
}
