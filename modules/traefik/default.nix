{ lib, ... }:
let
  inherit (lib) mkOption mkIf mkMerge;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    attrsOf
    anything
    submodule
    enum
    ;
in
{
  _class = "clan.service";
  manifest.name = "traefik";

  roles = {
    proxy = {
      interface = {
        # Allow freeform configuration that maps directly to services.traefik
        freeformType = attrsOf anything;

        options = {
          # Clan-specific convenience options

          # TLS/Certificate Management
          enableAutoTLS = mkOption {
            type = bool;
            default = true;
            description = "Enable automatic TLS certificate generation via ACME";
          };

          acmeEmail = mkOption {
            type = nullOr str;
            default = null;
            description = "Email address for ACME certificate generation";
          };

          certificateResolver = mkOption {
            type = enum [
              "letsencrypt"
              "tailscale"
              "custom"
            ];
            default = "letsencrypt";
            description = "Certificate resolver to use";
          };

          # Entry Points
          enableWebEntryPoint = mkOption {
            type = bool;
            default = true;
            description = "Enable HTTP entry point on port 80";
          };

          enableWebSecureEntryPoint = mkOption {
            type = bool;
            default = true;
            description = "Enable HTTPS entry point on port 443";
          };

          autoRedirectToHTTPS = mkOption {
            type = bool;
            default = true;
            description = "Automatically redirect HTTP to HTTPS";
          };

          # Dashboard
          enableDashboard = mkOption {
            type = bool;
            default = false;
            description = "Enable Traefik dashboard";
          };

          dashboardHost = mkOption {
            type = nullOr str;
            default = null;
            description = "Hostname for accessing the dashboard";
          };

          dashboardAuth = mkOption {
            type = enum [
              "none"
              "basic"
            ];
            default = "basic";
            description = "Authentication type for dashboard";
          };

          # Service Discovery
          services = mkOption {
            type = listOf (submodule {
              options = {
                name = mkOption {
                  type = str;
                  description = "Service identifier";
                };
                host = mkOption {
                  type = str;
                  description = "Hostname for the service";
                };
                backend = mkOption {
                  type = str;
                  description = "Backend URL (e.g., http://localhost:3000)";
                };
                enableAuth = mkOption {
                  type = bool;
                  default = false;
                  description = "Enable authentication for this service";
                };
                authType = mkOption {
                  type = enum [
                    "basic"
                    "tailscale"
                  ];
                  default = "basic";
                  description = "Type of authentication (basic or tailscale)";
                };
                tailscaleDomain = mkOption {
                  type = nullOr str;
                  default = null;
                  description = "Tailscale domain for authentication";
                };
                middlewares = mkOption {
                  type = listOf str;
                  default = [ ];
                  description = "List of middleware names to apply";
                };
              };
            });
            default = [ ];
            description = "High-level service definitions for automatic routing";
          };

          # Common Middlewares
          defaultMiddlewares = mkOption {
            type = listOf str;
            default = [ "security-headers" ];
            description = "Default middlewares to apply to all services";
          };

          # Advanced configuration passthrough
          staticConfigOptions = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Advanced static configuration options";
          };

          dynamicConfigOptions = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Advanced dynamic configuration options";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              lib,
              ...
            }:
            let
              # Get the extended settings
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                enableAutoTLS
                acmeEmail
                certificateResolver
                enableWebEntryPoint
                enableWebSecureEntryPoint
                autoRedirectToHTTPS
                enableDashboard
                dashboardHost
                dashboardAuth
                services
                defaultMiddlewares
                staticConfigOptions
                dynamicConfigOptions
                ;

              # Remove clan-specific options before passing to services.traefik
              traefikConfig = builtins.removeAttrs settings [
                "enableAutoTLS"
                "acmeEmail"
                "certificateResolver"
                "enableWebEntryPoint"
                "enableWebSecureEntryPoint"
                "autoRedirectToHTTPS"
                "enableDashboard"
                "dashboardHost"
                "dashboardAuth"
                "services"
                "defaultMiddlewares"
                "staticConfigOptions"
                "dynamicConfigOptions"
              ];

              # Build entry points configuration
              entryPoints = mkMerge [
                (mkIf enableWebEntryPoint {
                  web = {
                    address = ":80";
                  }
                  // (mkIf (autoRedirectToHTTPS && enableWebSecureEntryPoint) {
                    http.redirections.entrypoint = {
                      to = "websecure";
                      scheme = "https";
                    };
                  });
                })
                (mkIf enableWebSecureEntryPoint {
                  websecure = {
                    address = ":443";
                    http.tls.certResolver = mkIf enableAutoTLS certificateResolver;
                  };
                })
              ];

              # Build certificate resolvers
              certificateResolvers = mkIf enableAutoTLS (
                if certificateResolver == "letsencrypt" then
                  {
                    letsencrypt = {
                      acme = {
                        email = acmeEmail;
                        storage = "/var/lib/traefik/acme.json";
                        httpChallenge.entryPoint = "web";
                      };
                    };
                  }
                else if certificateResolver == "tailscale" then
                  {
                    tailscale = {
                      tailscale = { };
                    };
                  }
                else
                  { }
              );

              # Build dynamic configuration for services
              dynamicRouters = lib.listToAttrs (
                map (service: {
                  inherit (service) name;
                  value = {
                    rule = "Host(`${service.host}`)";
                    service = service.name;
                    entryPoints = [ "websecure" ];
                    middlewares =
                      defaultMiddlewares
                      ++ service.middlewares
                      ++ (lib.optional service.enableAuth "${service.name}-auth");
                    tls.certResolver = mkIf enableAutoTLS certificateResolver;
                  };
                }) services
              );

              dynamicServices = lib.listToAttrs (
                map (service: {
                  inherit (service) name;
                  value = {
                    loadBalancer.servers = [
                      { url = service.backend; }
                    ];
                  };
                }) services
              );

              # Build middlewares
              dynamicMiddlewares = mkMerge [
                # Security headers middleware
                (mkIf (builtins.elem "security-headers" defaultMiddlewares) {
                  security-headers = {
                    headers = {
                      customFrameOptionsValue = "SAMEORIGIN";
                      contentTypeNosniff = true;
                      browserXssFilter = true;
                      referrerPolicy = "strict-origin-when-cross-origin";
                      customResponseHeaders = {
                        "X-Robots-Tag" = "noindex,nofollow,nosnippet,noarchive,notranslate,noimageindex";
                      };
                    };
                  };
                })
                # Auth middlewares for services
                (lib.listToAttrs (
                  map (service: {
                    name = "${service.name}-auth";
                    value = mkIf service.enableAuth (
                      if (service.authType or "basic") == "tailscale" then
                        {
                          plugin.tailscale-connectivity = {
                            testDomain = service.tailscaleDomain or config.networking.domain or "example.ts.net";
                            sessionTimeout = "24h";
                            allowLocalhost = false;
                          };
                        }
                      else
                        {
                          basicAuth.usersFile =
                            config.clan.core.vars.generators."traefik-${service.name}-auth".files.htpasswd.path;
                        }
                    );
                  }) (lib.filter (s: s.enableAuth) services)
                ))
              ];

              # Dashboard configuration
              dashboardRouter = mkIf (enableDashboard && dashboardHost != null) {
                dashboard = {
                  rule = "Host(`${dashboardHost}`)";
                  service = "api@internal";
                  entryPoints = [ "websecure" ];
                  middlewares = if dashboardAuth == "basic" then [ "dashboard-auth" ] else [ ];
                  tls.certResolver = mkIf enableAutoTLS certificateResolver;
                };
              };

              dashboardMiddleware = mkIf (enableDashboard && dashboardAuth == "basic") {
                dashboard-auth = {
                  basicAuth.usersFile = config.clan.core.vars.generators.traefik-dashboard-auth.files.htpasswd.path;
                };
              };

            in
            {
              # Enable Traefik with the configuration
              services.traefik = mkMerge [
                {
                  enable = true;

                  # Static configuration
                  staticConfigOptions = mkMerge [
                    {
                      api = mkIf enableDashboard {
                        dashboard = true;
                      };

                      inherit entryPoints;

                      certificatesResolvers = certificateResolvers;

                      providers.file = {
                        directory = "/etc/traefik/dynamic";
                        watch = true;
                      };

                      # Enable Tailscale plugin if any service uses it
                      experimental.plugins.tailscale-connectivity = {
                        modulename = "github.com/hhftechnology/tailscale-access";
                        version = "v2.0.0";
                      };
                    }
                    staticConfigOptions
                  ];

                  # Dynamic configuration
                  dynamicConfigOptions = mkMerge [
                    {
                      http = {
                        routers = mkMerge [
                          dynamicRouters
                          (mkIf (enableDashboard && dashboardHost != null) dashboardRouter)
                        ];

                        services = dynamicServices;

                        middlewares = mkMerge [
                          dynamicMiddlewares
                          (mkIf (enableDashboard && dashboardAuth == "basic") dashboardMiddleware)
                        ];
                      };
                    }
                    dynamicConfigOptions
                  ];
                }
                traefikConfig
              ];

              # Open firewall ports
              networking.firewall.allowedTCPPorts =
                lib.optional enableWebEntryPoint 80 ++ lib.optional enableWebSecureEntryPoint 443;

              # Ensure traefik can read certificates
              users.users.traefik = mkIf enableAutoTLS {
                extraGroups = [ "acme" ];
              };

              # Create directory for dynamic configuration
              systemd.tmpfiles.rules = [
                "d /etc/traefik 0755 traefik traefik -"
                "d /etc/traefik/dynamic 0755 traefik traefik -"
              ];

              # Ensure ACME email is set if auto TLS is enabled with Let's Encrypt
              assertions = [
                {
                  assertion = !enableAutoTLS || certificateResolver != "letsencrypt" || acmeEmail != null;
                  message = "acmeEmail must be set when using Let's Encrypt certificates";
                }
                {
                  assertion =
                    !enableDashboard
                    || dashboardHost != null
                    || !config.services.traefik.staticConfigOptions.api.dashboard;
                  message = "dashboardHost must be set when dashboard is enabled";
                }
              ];
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, config, ... }:
      let
        # Generate auth configurations for services that need basic auth
        authServices = lib.filter (s: s.enableAuth && (s.authType or "basic") == "basic") (
          config.nodes.${config.networking.hostName}.services.traefik.proxy.services or [ ]
        );

        needsDashboardAuth =
          (config.nodes.${config.networking.hostName}.services.traefik.proxy.enableDashboard or false)
          &&
            (config.nodes.${config.networking.hostName}.services.traefik.proxy.dashboardAuth or "basic")
            == "basic";
      in
      {
        # Ensure traefik package is available
        environment.systemPackages = [ pkgs.traefik ];

        # Create vars generator for dashboard auth if needed
        clan.core.vars.generators = mkMerge [
          (mkIf needsDashboardAuth {
            traefik-dashboard-auth = {
              files.htpasswd = {
                owner = "traefik";
                group = "traefik";
                mode = "0400";
              };
              runtimeInputs = with pkgs; [ apacheHttpd ];
              prompts.admin_password = {
                description = "Traefik dashboard admin password";
                type = "hidden";
                persist = true;
              };
              script = ''
                htpasswd -nbB admin "$prompts/admin_password" > "$out/htpasswd"
              '';
            };
          })

          # Create auth generators for each service that needs it
          (lib.listToAttrs (
            map (service: {
              name = "traefik-${service.name}-auth";
              value = {
                files.htpasswd = {
                  owner = "traefik";
                  group = "traefik";
                  mode = "0400";
                };
                runtimeInputs = with pkgs; [ apacheHttpd ];
                prompts."${service.name}_password" = {
                  description = "Password for ${service.name} service";
                  type = "hidden";
                  persist = true;
                };
                script = ''
                  htpasswd -nbB ${service.name} "$prompts/${service.name}_password" > "$out/htpasswd"
                '';
              };
            }) authServices
          ))
        ];
      };
  };
}
