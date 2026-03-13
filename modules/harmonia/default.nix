{ lib, ... }:
let
  inherit (lib) mkDefault;
  inherit (lib.types) attrsOf anything;
in
{
  _class = "clan.service";
  manifest = {
    name = "harmonia";
    readme = "Nix binary cache server (harmonia) that serves the local nix store over HTTP";
  };

  roles = {
    server = {
      description = "Harmonia binary cache server";
      interface = {
        freeformType = attrsOf anything;
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              cfg = extendSettings {
                port = mkDefault 5000;
                workers = mkDefault 4;
                maxConnectionRate = mkDefault 256;
                priority = mkDefault 30;
              };
            in
            {
              services.harmonia.cache = {
                enable = true;
                signKeyPaths = [
                  config.clan.core.vars.generators.nix-signing-key.files."key".path
                ];
                settings = {
                  bind = "[::]:${toString cfg.port}";
                  inherit (cfg) workers;
                  max_connection_rate = cfg.maxConnectionRate;
                  inherit (cfg) priority;
                };
              };

              networking.firewall.allowedTCPPorts = [ cfg.port ];
            };
        };
    };
  };

  perMachine = _: {
    nixosModule = _: { };
  };
}
