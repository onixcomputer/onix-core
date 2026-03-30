{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  inherit (lib) mkDefault mkIf;
in
{
  _class = "clan.service";
  manifest = {
    name = "vaultwarden";
    readme = "Vaultwarden password manager server for secure credential storage";
  };

  roles = {
    server = {
      description = "Vaultwarden password manager server";
      interface = mkSettings.mkInterface schema.server;

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              localSettings = extendSettings (
                (ms.mkDefaults schema.server)
                // {
                  # Config-dependent default — generated secret path
                  adminTokenFile =
                    mkDefault
                      config.clan.core.vars.generators."vaultwarden-${instanceName}".files.admin_token.path;
                }
              );

              # Extract known options from freeform settings
              inherit (localSettings) adminTokenFile;

              # Everything else is a Vaultwarden environment variable
              environment = removeAttrs localSettings [
                "adminTokenFile"
              ];
            in
            {
              services.vaultwarden = {
                enable = true;
                config = environment;
              };

              systemd.services.vaultwarden = mkIf (adminTokenFile != null) {
                serviceConfig = {
                  LoadCredential = [ "admin_token:${adminTokenFile}" ];
                };
                environment.ADMIN_TOKEN_FILE = "%d/admin_token";
              };

              clan.core.vars.generators."vaultwarden-${instanceName}" = {
                files.admin_token = { };
                runtimeInputs = with pkgs; [
                  coreutils
                  openssl
                ];
                script = ''
                  openssl rand -base64 48 > "$out/admin_token"
                '';
              };

              networking.firewall.allowedTCPPorts =
                lib.optional (environment ? ROCKET_PORT) environment.ROCKET_PORT
                ++ lib.optional (environment ? WEBSOCKET_PORT) environment.WEBSOCKET_PORT;
            };
        };
    };
  };
}
