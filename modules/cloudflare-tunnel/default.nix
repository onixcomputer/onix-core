{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    ;
  inherit (lib.types)
    str
    nullOr
    attrsOf
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "cloudflare-tunnel";
    readme = "Cloudflare tunnel service for secure internet exposure of local services";
  };

  roles = {
    default = {
      description = "Cloudflare tunnel client that exposes local services to the internet";
      interface = {
        options = {
          tunnelName = mkOption {
            type = nullOr str;
            default = null;
            description = "Name for the Cloudflare tunnel (defaults to machine hostname)";
          };

          ingress = mkOption {
            type = attrsOf str;
            default = { };
            description = ''
              Ingress rules mapping hostnames to backend services.
              Example: { "app.example.com" = "http://localhost:3000"; }
            '';
          };

          autoIngress = mkOption {
            type = attrsOf str;
            default = { };
            description = ''
              Automatically resolve ingress backend URLs from service exports.
              Maps hostnames to export service endpoint names.
              Example: { "vault.robitzs.ch" = "vaultwarden"; }
              The service must export serviceEndpoints.<name> with a url field.
              Manual ingress entries take precedence over auto-resolved ones.
            '';
          };
        };
      };

      perInstance =
        {
          instanceName,
          extendSettings,
          exports,
          ...
        }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                tunnelName = mkDefault config.networking.hostName;
              };

              # Resolve auto-ingress from service exports
              autoIngress = localSettings.autoIngress or { };
              resolvedAutoIngress =
                if autoIngress == { } then
                  { }
                else
                  lib.mapAttrs (
                    hostname: serviceName:
                    let
                      # Search all instances for the serviceEndpoint
                      matchingInstances = lib.filterAttrs (
                        _instanceName: instanceData: (instanceData.serviceEndpoints.${serviceName} or null) != null
                      ) (exports.instances or { });

                      availableInstances = lib.attrNames (exports.instances or { });
                      availableEndpoints = lib.concatStringsSep ", " (
                        lib.flatten (
                          lib.mapAttrsToList (_: instanceData: lib.attrNames (instanceData.serviceEndpoints or { })) (
                            exports.instances or { }
                          )
                        )
                      );
                    in
                    if matchingInstances != { } then
                      (lib.head (lib.attrValues matchingInstances)).serviceEndpoints.${serviceName}.url
                    else
                      throw ''
                        cloudflare-tunnel: No export found for service '${serviceName}' (referenced by autoIngress for ${hostname})
                        Available instances: ${lib.concatStringsSep ", " availableInstances}
                        Available endpoints: ${availableEndpoints}
                      ''
                  ) autoIngress;

              # Manual ingress takes precedence over auto-resolved
              mergedIngress = resolvedAutoIngress // localSettings.ingress;

              inherit (localSettings) tunnelName;
              ingress = mergedIngress;

              # Tunnel credentials file path
              tunnelCredentialsFile = "/var/lib/cloudflared/${tunnelName}.json";

              # Extract all hostnames from ingress rules
              hostnames = builtins.attrNames mergedIngress;

              # Get the setup script
              setupScript = ./setup-tunnel.sh;

              # Generate summary for the script output
              ingressSummary = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (hostname: service: "  - https://${hostname} → ${service}") mergedIngress
              );
            in
            mkIf (mergedIngress != { }) {
              # Cloudflare tunnel setup service
              systemd.services."cloudflare-tunnel-setup-${tunnelName}" = {
                description = "Setup Cloudflare tunnel ${tunnelName}";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                before = [ "cloudflared-tunnel-${tunnelName}.service" ];

                # Always run to ensure DNS records are up to date
                # The script will handle existing tunnels gracefully

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "cloudflared";
                  LoadCredential = [
                    "api_token:${config.clan.core.vars.generators."cloudflare-${instanceName}".files.api_token.path}"
                  ];
                  # Restart on failure with delay
                  Restart = "on-failure";
                  RestartSec = "30s";
                };

                # Set up environment variables for the script
                environment = {
                  TUNNEL_NAME = tunnelName;
                  TUNNEL_CREDENTIALS_FILE = tunnelCredentialsFile;
                  HOSTNAMES = lib.concatStringsSep " " hostnames;
                  FIRST_HOSTNAME = if hostnames != [ ] then builtins.head hostnames else "";
                  INGRESS_SUMMARY = ingressSummary;
                };

                script = builtins.readFile setupScript;

                path = with pkgs; [
                  curl
                  jq
                  openssl
                  coreutils
                  gnugrep
                ];

                wantedBy = [ "multi-user.target" ];
              };

              # Cloudflare tunnel service
              services.cloudflared = {
                enable = true;
                tunnels."${tunnelName}" = {
                  credentialsFile = tunnelCredentialsFile;
                  default = "http_status:404";
                  inherit ingress;
                };
              };

              # Shared API token generator (per instance, shared across machines)
              clan.core.vars.generators."cloudflare-${instanceName}" = {
                share = true; # Share across all machines in the instance
                files.api_token = {
                  secret = true;
                  deploy = true;
                };

                prompts.api_token = {
                  description = ''
                    Cloudflare API token for creating tunnels.

                    To create one:
                    1. Go to https://dash.cloudflare.com/profile/api-tokens
                    2. Click "Create Token"
                    3. Use "Custom token" template with:
                       - Account > Cloudflare Tunnel > Edit
                       - Zone > DNS > Edit
                       - Zone Resources > Include > All zones
                  '';
                  type = "hidden";
                  persist = true;
                };

                runtimeInputs = [ pkgs.coreutils ];

                script = ''
                  cat "$prompts/api_token" | tr -d '\n' > "$out/api_token"
                '';
              };
            };
        };
    };
  };
}
