{ lib, ... }:
let
  inherit (lib) mkOption mkDefault;
  inherit (lib.types)
    str
    listOf
    attrsOf
    anything
    enum
    nullOr
    ;
in
{
  _class = "clan.service";
  manifest.name = "ddclient";

  roles = {
    server = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          # Clan-specific convenience options
          domains = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of domain names to update with dynamic DNS";
            example = [
              "example.com"
              "subdomain.example.com"
            ];
          };

          dnsProvider = mkOption {
            type = nullOr (enum [
              "cloudflare"
              "namecheap"
              "dyndns"
              "noip"
              "freedns"
              "custom"
            ]);
            default = null;
            description = ''
              DNS provider to use. Setting this will automatically configure
              the appropriate protocol and server settings.
            '';
          };

          updateInterval = mkOption {
            type = str;
            default = "10min";
            description = "How often to check and update DNS records";
            example = "5min";
          };

          # Removed autoGeneratePassword - we handle this based on provider

          cloudflareZone = mkOption {
            type = nullOr str;
            default = null;
            description = "Cloudflare Zone ID (required when using Cloudflare provider)";
            example = "1234567890abcdef1234567890abcdef";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = localSettings;

              # Extract clan-specific options
              domains = settings.domains or [ ];
              dnsProvider = settings.dnsProvider or null;
              updateInterval = settings.updateInterval or "10min";
              cloudflareZone = settings.cloudflareZone or null;

              # Remove clan-specific options before passing to services.ddclient
              serviceConfig = builtins.removeAttrs settings [
                "domains"
                "dnsProvider"
                "updateInterval"
                "cloudflareZone"
              ];

              # Provider presets
              providerConfig = {
                cloudflare = {
                  protocol = "cloudflare";
                  server = "api.cloudflare.com/client/v4";
                  ssl = true;
                };
                namecheap = {
                  protocol = "namecheap";
                  server = "dynamicdns.park-your-domain.com";
                  ssl = true;
                };
                dyndns = {
                  protocol = "dyndns2";
                  server = "members.dyndns.org";
                  ssl = true;
                };
                noip = {
                  protocol = "noip";
                  server = "dynupdate.no-ip.com";
                  ssl = true;
                };
                freedns = {
                  protocol = "freedns";
                  server = "freedns.afraid.org";
                  ssl = true;
                };
              };

              # Extend settings with defaults based on provider
              localSettings = extendSettings (
                if dnsProvider == "cloudflare" then
                  {
                    passwordFile = mkDefault config.clan.core.vars.generators.ddclient-cloudflare.files.api_token.path;
                    zone = mkDefault cloudflareZone;
                  }
                else if dnsProvider != null then
                  {
                    passwordFile = mkDefault config.clan.core.vars.generators.ddclient.files.password.path;
                  }
                else
                  { }
              );
            in
            {
              services.ddclient = lib.mkMerge [
                {
                  enable = true;
                  interval = updateInterval;
                }
                # Add provider presets if specified
                (lib.mkIf (dnsProvider != null && dnsProvider != "custom") providerConfig.${dnsProvider})
                # Add domains if specified
                (lib.mkIf (domains != [ ]) {
                  inherit domains;
                })
                # Pass through all freeform configuration
                serviceConfig
              ];
            };
        };
    };
  };

  perMachine = _: {
    nixosModule =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      let
        cfg = config.services.ddclient;
        # Determine which provider is being used
        providerSettings = config.clan.services.ddclient.roles.server.settings or { };
        dnsProvider = providerSettings.dnsProvider or null;
      in
      {
        clan.core.vars.generators = lib.mkMerge [
          # Cloudflare-specific generator
          (lib.mkIf (cfg.enable && dnsProvider == "cloudflare") {
            ddclient-cloudflare = {
              prompts.api_token = {
                description = "Cloudflare API Token with Zone:DNS:Edit permissions";
                type = "hidden";
              };
              script = ''
                cat "$prompts"/api_token > "$out"/api_token
              '';
              files.api_token = {
                mode = "0400";
              };
            };
          })

          # Generic password generator for other providers
          (lib.mkIf (cfg.enable && dnsProvider != null && dnsProvider != "cloudflare") {
            ddclient = {
              prompts = { }; # No prompts for auto-generation
              runtimeInputs = [ pkgs.pwgen ];
              script = ''
                pwgen -s 32 1 > "$out"/password
              '';
              files.password = {
                mode = "0400";
              };
            };
          })
        ];
      };
  };
}
