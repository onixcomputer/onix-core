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
    anything
    ;
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
      interface = {
        # Freeform module - any attribute becomes a Vaultwarden environment variable
        freeformType = attrsOf anything;

        options = {
          # Optional secret management
          adminTokenFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to file containing the admin token";
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, ... }:
            let
              localSettings = extendSettings {
                adminTokenFile =
                  mkDefault
                    config.clan.core.vars.generators."vaultwarden-${instanceName}".files.admin_token.path;

                # Minimal defaults
                DOMAIN = mkDefault "https://vaultwarden.localhost";
                ROCKET_PORT = mkDefault 8222;
                WEBSOCKET_ENABLED = mkDefault true;
                WEBSOCKET_PORT = mkDefault 3012;
                SIGNUPS_ALLOWED = mkDefault false;
                INVITATIONS_ALLOWED = mkDefault true;
                SHOW_PASSWORD_HINT = mkDefault false;
              };

              # Extract known options from freeform settings
              inherit (localSettings) adminTokenFile;

              # Everything else is a Vaultwarden environment variable
              environment = removeAttrs localSettings [
                "adminTokenFile"
              ];
            in
            {
              # Main Vaultwarden service
              services.vaultwarden = {
                enable = true;
                config = environment;
              };

              # Set admin token if provided
              systemd.services.vaultwarden = mkIf (adminTokenFile != null) {
                serviceConfig = {
                  LoadCredential = [ "admin_token:${adminTokenFile}" ];
                };
                environment.ADMIN_TOKEN_FILE = "%d/admin_token";
              };

              # Instance-specific admin token generator
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

              # Open firewall ports if configured
              networking.firewall.allowedTCPPorts =
                lib.optional (environment ? ROCKET_PORT) environment.ROCKET_PORT
                ++ lib.optional (environment ? WEBSOCKET_PORT) environment.WEBSOCKET_PORT;
            };
        };
    };
  };

}
