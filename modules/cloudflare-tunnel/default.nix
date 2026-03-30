{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  inherit (lib) mkDefault mkIf;
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
      interface = mkSettings.mkInterface schema.default;

      perInstance =
        {
          instanceName,
          extendSettings,
          ...
        }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              localSettings = extendSettings (
                (ms.mkDefaults schema.default)
                // {
                  # Config-dependent default — falls back to machine hostname
                  tunnelName = mkDefault config.networking.hostName;
                }
              );

              inherit (localSettings) tunnelName ingress;

              # Tunnel credentials file path
              tunnelCredentialsFile = "/var/lib/cloudflared/${tunnelName}.json";

              # Extract all hostnames from ingress rules
              hostnames = builtins.attrNames ingress;

              # Generate summary for the script output
              ingressSummary = lib.concatStringsSep "\n" (
                lib.mapAttrsToList (hostname: service: "  - https://${hostname} → ${service}") ingress
              );

              # Setup script extracted to setup-tunnel.sh for readability.
              # Pure shell — no Nix interpolation needed. All config passed
              # via systemd environment variables (see service definition below).
              setupTunnelScript = pkgs.writeShellApplication {
                name = "cloudflare-tunnel-setup-${tunnelName}";
                runtimeInputs = with pkgs; [
                  curl
                  jq
                  openssl
                  coreutils
                  gnugrep
                ];
                text = builtins.readFile ./setup-tunnel.sh;
              };
            in
            mkIf (ingress != { }) {
              # Cloudflare tunnel setup service
              systemd.services."cloudflare-tunnel-setup-${tunnelName}" = {
                description = "Setup Cloudflare tunnel ${tunnelName}";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                before = [ "cloudflared-tunnel-${tunnelName}.service" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  StateDirectory = "cloudflared";
                  LoadCredential = [
                    "api_token:${config.clan.core.vars.generators."cloudflare-${instanceName}".files.api_token.path}"
                  ];
                  ExecStart = lib.getExe setupTunnelScript;
                  Restart = "on-failure";
                  RestartSec = "30s";
                };

                # Environment variables consumed by the script
                environment = {
                  TUNNEL_NAME = tunnelName;
                  TUNNEL_CREDENTIALS_FILE = tunnelCredentialsFile;
                  HOSTNAMES = lib.concatStringsSep " " hostnames;
                  FIRST_HOSTNAME = if hostnames != [ ] then builtins.head hostnames else "";
                  INGRESS_SUMMARY = ingressSummary;
                };

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
