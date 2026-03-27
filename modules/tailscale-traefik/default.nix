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
  manifest = {
    name = "tailscale-traefik";
    readme = "Traefik reverse proxy with Tailscale integration for secure routing";
  };

  roles = {
    server = {
      description = "Traefik reverse proxy server with Tailscale integration";
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

                public = mkOption {
                  type = bool;
                  default = false;
                  description = "Use public IP instead of Tailscale IP for this service's DNS record";
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

              # All options have mkOption defaults — no `or` fallbacks needed.
              # tailscaleAuthKeyFile is the sole exception: its default
              # depends on config (vars path), which can't be expressed in mkOption.
              inherit (cfg)
                domain
                email
                services
                additionalSubdomains
                traefikDashboard
                sslRedirect
                ddclientInterval
                extraTraefikConfig
                extraDynamicConfig
                securityHeaders
                dnsPropagationCheck
                dnsResolvers
                dnsPropagationDelay
                tailscaleExitNode
                tailscaleSSH
                tailscalePort
                ;
              tailscaleAuthKeyFile =
                if cfg.tailscaleAuthKeyFile != null then
                  cfg.tailscaleAuthKeyFile
                else
                  config.clan.core.vars.generators.tailscale-traefik.files.tailscale_auth_key.path;

              # Resolve subdomain: use explicit override or fall back to service name.
              resolveSubdomain = name: svc: if svc.subdomain != null then svc.subdomain else name;

              # Partition services by public/private, resolve subdomains once.
              publicSubdomainsList = lib.filter (x: x != null) (
                lib.mapAttrsToList (name: svc: if svc.public then resolveSubdomain name svc else null) services
              );

              privateSubdomainsList = lib.filter (x: x != null) (
                (lib.mapAttrsToList (name: svc: if !svc.public then resolveSubdomain name svc else null) services)
                ++ additionalSubdomains
                ++ (lib.optional traefikDashboard "traefik")
              );

              # Script to get Tailscale IP
              getTailscaleIP = pkgs.writeShellApplication {
                name = "get-tailscale-ip";
                runtimeInputs = [ pkgs.tailscale ];
                text = ''
                  tailscale ip -4 | head -n1
                '';
              };

              # Check if any services are public
              hasPublicServices = publicSubdomainsList != [ ];

              # Generate Traefik routes
              serviceRouters = lib.mapAttrs' (
                name: svc:
                let
                  subdomain = resolveSubdomain name svc;
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
                  // svc.extraRouterConfig
                )
              ) services;

              # Generate Traefik services
              serviceBackends = lib.mapAttrs' (
                name: svc:
                let
                  subdomain = resolveSubdomain name svc;
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
                    # First try explicit portPath
                    if svc.portPath != null then
                      getConfigValue svc.portPath config
                    # Then try built-in detectors
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
                  // svc.extraServiceConfig
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

              # Shared ddclient script builder — the private and public services
              # differ only in IP source and subdomain list. Single source of truth
              # for the Cloudflare zone lookup + DNS record upsert + config generation.
              mkDdclientScript =
                {
                  scriptName,
                  ipSourceCmd, # shell expression that prints the IP
                  useDirective, # ddclient "use=" line
                  subdomainsList,
                  runtimeDir,
                }:
                pkgs.writeShellApplication {
                  name = scriptName;
                  # SC2043: false positive — Nix interpolates a space-separated list
                  excludeShellChecks = [ "SC2043" ];
                  runtimeInputs = [
                    pkgs.curl
                    pkgs.jq
                    pkgs.coreutils
                    pkgs.ddclient
                  ];
                  text = ''
                    CF_TOKEN=$(cat ${cloudflareTokenFile})
                    ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${domain}" \
                      -H "Authorization: Bearer $CF_TOKEN" \
                      -H "Content-Type: application/json" | jq -r '.result[0].id')

                    CURRENT_IP=$(${ipSourceCmd})
                    for subdomain in ${lib.concatStringsSep " " subdomainsList}; do
                      echo "Checking if $subdomain.${domain} exists..."

                      RECORD_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$subdomain.${domain}" \
                        -H "Authorization: Bearer $CF_TOKEN" \
                        -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

                      if [ -z "$RECORD_ID" ]; then
                        echo "Creating DNS record for $subdomain.${domain} → $CURRENT_IP"
                        curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                          -H "Authorization: Bearer $CF_TOKEN" \
                          -H "Content-Type: application/json" \
                          --data "{\"type\":\"A\",\"name\":\"$subdomain.${domain}\",\"content\":\"$CURRENT_IP\",\"ttl\":1,\"proxied\":false}" \
                          | jq -r '.success'
                      else
                        echo "DNS record for $subdomain.${domain} already exists"
                      fi
                    done

                    cat > /run/${runtimeDir}/ddclient.conf <<EOF
                    ssl=yes
                    protocol=cloudflare
                    zone=${domain}
                    login=token
                    password=$(cat ${cloudflareTokenFile})
                    ${useDirective}
                    verbose=yes
                    pid=/run/${runtimeDir}.pid
                    cache=/var/lib/${runtimeDir}/ddclient.cache
                    ${lib.concatMapStringsSep "," (s: "${s}.${domain}") subdomainsList}
                    EOF

                    chmod 600 /run/${runtimeDir}/ddclient.conf
                    ddclient -daemon ${toString ddclientInterval} -file /run/${runtimeDir}/ddclient.conf
                  '';
                };

            in
            {
              assertions = [
                {
                  assertion = domain != "";
                  message = "tailscale-traefik: 'domain' must be non-empty";
                }
                {
                  assertion = email != "";
                  message = "tailscale-traefik: 'email' must be non-empty";
                }
                {
                  assertion = dnsResolvers != [ ];
                  message = "tailscale-traefik: 'dnsResolvers' must contain at least one resolver";
                }
              ];

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

                # DDClient configuration - always disabled as we use dual ddclient approach
                ddclient.enable = false;

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
                              resolvers = dnsResolvers;
                              # Traefik v3 renamed these under propagation.*
                              propagation = {
                                delayBeforeChecks = dnsPropagationDelay;
                              }
                              // (lib.optionalAttrs (!dnsPropagationCheck) {
                                disableChecks = true;
                              });
                            };
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
              networking.firewall = mkMerge [
                {
                  enable = mkDefault true;
                  checkReversePath = "loose";
                  trustedInterfaces = [ "tailscale0" ];
                  allowedUDPPorts = [ tailscalePort ];

                  interfaces = {
                    tailscale0 = {
                      allowedTCPPorts = [
                        80
                        443
                      ];
                    };
                  };
                }
                (mkIf hasPublicServices {
                  # Also open ports on all interfaces for public access
                  allowedTCPPorts = [
                    80
                    443
                  ];
                })
              ];

              # NAT configuration for exit nodes
              networking.nat = mkIf tailscaleExitNode {
                enable = true;
                externalInterface = mkDefault (mkIf (config.networking.interfaces ? "eth0") "eth0");
                internalInterfaces = [ "tailscale0" ];
              };

              # Service dependencies
              systemd.services = mkMerge [
                (mkIf (privateSubdomainsList != [ ]) {
                  ddclient-private = {
                    description = "Dynamic DNS Client (Private/Tailscale domains)";
                    after = [
                      "network-online.target"
                      "tailscale.service"
                      "traefik.service"
                    ];
                    wants = [ "network-online.target" ];
                    wantedBy = [ "multi-user.target" ];
                    partOf = [ "traefik.service" ];

                    serviceConfig =
                      let
                        waitForTailscale = pkgs.writeShellApplication {
                          name = "ddclient-private-wait-tailscale";
                          runtimeInputs = [ pkgs.tailscale ];
                          text = ''
                            echo "Waiting for Tailscale to be ready..."
                            ready=false
                            for i in $(seq 1 30); do
                              if ${lib.getExe getTailscaleIP} >/dev/null 2>&1; then
                                echo "Tailscale IP available: $(${lib.getExe getTailscaleIP})"
                                ready=true
                                break
                              fi
                              echo "Attempt $i/30..."
                              sleep 2
                            done

                            if [ "$ready" = "false" ]; then
                              echo "ERROR: Tailscale not ready after 60s"
                              exit 1
                            fi
                          '';
                        };
                      in
                      {
                        Type = "forking";
                        PIDFile = "/run/ddclient-private.pid";
                        RuntimeDirectory = "ddclient-private";
                        StateDirectory = "ddclient-private";
                        ExecStartPre = lib.getExe waitForTailscale;
                        ExecStart = lib.getExe (mkDdclientScript {
                          scriptName = "ddclient-private-start";
                          ipSourceCmd = lib.getExe getTailscaleIP;
                          useDirective = "use=cmd, cmd='${lib.getExe getTailscaleIP}'";
                          subdomainsList = privateSubdomainsList;
                          runtimeDir = "ddclient-private";
                        });
                      };

                    restartTriggers = [
                      (builtins.toString privateSubdomainsList)
                      (builtins.hashString "sha256" (builtins.toJSON services))
                    ];
                  };
                })

                (mkIf (publicSubdomainsList != [ ]) {
                  ddclient-public = {
                    description = "Dynamic DNS Client (Public domains)";
                    after = [
                      "network-online.target"
                      "traefik.service"
                    ];
                    wants = [ "network-online.target" ];
                    wantedBy = [ "multi-user.target" ];
                    partOf = [ "traefik.service" ];

                    serviceConfig = {
                      Type = "forking";
                      PIDFile = "/run/ddclient-public.pid";
                      RuntimeDirectory = "ddclient-public";
                      StateDirectory = "ddclient-public";
                      ExecStart = lib.getExe (mkDdclientScript {
                        scriptName = "ddclient-public-start";
                        ipSourceCmd = "curl -s https://ipinfo.io/ip";
                        useDirective = "use=web, web=ipinfo.io/ip";
                        subdomainsList = publicSubdomainsList;
                        runtimeDir = "ddclient-public";
                      });
                    };

                    restartTriggers = [
                      (builtins.toString publicSubdomainsList)
                      (builtins.hashString "sha256" (builtins.toJSON services))
                    ];
                  };
                })

                # Traefik service configuration
                {
                  traefik = {
                    after = [ "tailscale.service" ];
                    wants = [ "tailscale.service" ];

                    restartTriggers = [
                      (builtins.toJSON services)
                    ];

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
                      ${lib.concatMapStringsSep "\n" (r: "nameserver ${r}") dnsResolvers}
                      EOF
                    '';
                  };
                }
              ];

              # Timer services for the custom ddclient instances
              systemd.timers = mkMerge [
                (mkIf (privateSubdomainsList != [ ]) {
                  ddclient-private = {
                    wantedBy = [ "timers.target" ];
                    timerConfig = {
                      OnBootSec = "5m";
                      OnUnitActiveSec = "${toString ddclientInterval}s";
                    };
                  };
                })
                (mkIf (publicSubdomainsList != [ ]) {
                  ddclient-public = {
                    wantedBy = [ "timers.target" ];
                    timerConfig = {
                      OnBootSec = "5m";
                      OnUnitActiveSec = "${toString ddclientInterval}s";
                    };
                  };
                })
              ];

              # Ensure required packages
              environment.systemPackages = with pkgs; [
                tailscale
                curl
                dig
                jq
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
