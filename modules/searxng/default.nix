{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";
  manifest = {
    name = "searxng";
    readme = builtins.readFile ./README.md;
  };

  roles.server = {
    description = "SearXNG metasearch server";
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
            settings = extendSettings (mkSettings.mkDefaults schema.server);
            generatorName = "searxng-${instanceName}";
            secretBytes = 32;
            kagiGeneratorName = "${generatorName}-kagi";
            maximumKagiTimeoutSeconds = 30;
            tidalGeneratorName = "${generatorName}-tidal";
            tidalTimeoutSeconds = 10;
            tidalEnvironmentFile = config.clan.core.vars.generators.${tidalGeneratorName}.files."env-file".path;
            customEngines = settings.enableKagi || settings.enableDeveloperEngines || settings.enableTidal;
            kagiEnvironmentFile = config.clan.core.vars.generators.${kagiGeneratorName}.files."env-file".path;
            listenerAddress =
              if lib.hasInfix ":" settings.bindAddress then "[${settings.bindAddress}]" else settings.bindAddress;
          in
          lib.mkMerge [
            {
              assertions = [
                {
                  assertion = settings.enableKagi || !(settings.kagiDefault || settings.kagiHealthCheck);
                  message = "Kagi defaults and health checks require enableKagi.";
                }
                {
                  assertion =
                    settings.kagiTimeoutSeconds > 0 && settings.kagiTimeoutSeconds <= maximumKagiTimeoutSeconds;
                  message = "Kagi timeout must be positive and at most ${toString maximumKagiTimeoutSeconds} seconds.";
                }
                {
                  assertion = builtins.match "[A-Za-z0-9:.%_-]+" settings.bindAddress != null;
                  message = "SearXNG bindAddress must be a nonempty address without whitespace or URL syntax.";
                }
                {
                  assertion =
                    settings.baseUrl == null || builtins.match "https?://[^[:space:]]+" settings.baseUrl != null;
                  message = "SearXNG baseUrl must be null or an HTTP or HTTPS URL.";
                }
                {
                  assertion = !settings.openFirewall || settings.firewallInterface != "";
                  message = "SearXNG requires a firewallInterface when openFirewall is true.";
                }
              ];

              # Reuse the locked NixOS adapter and its SearXNG package.
              # uWSGI avoids the built-in HTTP server's query access logs.
              services.searx = {
                enable = true;
                package =
                  if customEngines then
                    import ./kagi-package.nix {
                      inherit pkgs;
                      inherit (settings) enableKagi enableDeveloperEngines enableTidal;
                    }
                  else
                    pkgs.searxng;
                configureUwsgi = true;
                configureNginx = false;
                redisCreateLocally = settings.limiter;
                environmentFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
                uwsgiConfig = {
                  http = "${listenerAddress}:${toString settings.port}";
                  disable-logging = true;
                };
                settings = {
                  use_default_settings = true;
                  general = {
                    debug = false;
                    instance_name = settings.instanceName;
                  };
                  server = {
                    inherit (settings) limiter port;
                    bind_address = settings.bindAddress;
                    secret_key = "$SEARX_SECRET_KEY";
                    base_url = lib.mkIf (settings.baseUrl != null) settings.baseUrl;
                  };
                  search.formats = [ "html" ] ++ lib.optional settings.enableJson "json";
                  engines = lib.mkIf customEngines (
                    lib.optionals settings.enableKagi [
                      {
                        name = "kagi-private";
                        engine = "kagi_session";
                        shortcut = "kg";
                        categories = [
                          "general"
                          "web"
                        ];
                        disabled = !settings.kagiDefault;
                        timeout = settings.kagiTimeoutSeconds;
                        session_token = "$KAGI_SESSION_TOKEN";
                        tokens = [ "$KAGI_ENGINE_TOKEN" ];
                      }
                    ]
                    ++ lib.optionals settings.enableDeveloperEngines (import ./developer-engines.nix)
                    ++ lib.optionals settings.enableTidal [
                      {
                        name = "tidal";
                        engine = "tidal_catalog";
                        shortcut = "tidal";
                        categories = [ "music" ];
                        disabled = false;
                        timeout = tidalTimeoutSeconds;
                        session_token = "$TIDAL_SESSION_TOKEN";
                        tokens = [ (if settings.enableKagi then "$KAGI_ENGINE_TOKEN" else "$TIDAL_ENGINE_TOKEN") ];
                      }
                      {
                        name = "youtube";
                        engine = "youtube_noapi";
                        shortcut = "yt";
                        disabled = false;
                      }
                    ]
                  );
                };
              };

              clan.core.vars.generators = {
                ${generatorName} = {
                  files."env-file" = {
                    secret = true;
                    mode = "0400";
                  };
                  runtimeInputs = [ pkgs.openssl ];
                  script = ''
                    secret_key="$(openssl rand -hex ${toString secretBytes})" || exit 1
                    printf 'SEARX_SECRET_KEY=%s\n' "$secret_key" > "$out/env-file"
                  '';
                };

                ${tidalGeneratorName} = lib.mkIf settings.enableTidal {
                  files = {
                    "env-file" = {
                      secret = true;
                      mode = "0400";
                    };
                    "access-token" = {
                      secret = true;
                      deploy = false;
                    };
                    "session-token".deploy = false;
                  };
                  prompts."session-token" = {
                    description = "Current Drift Tidal access token only; never a refresh token";
                    type = "hidden";
                    persist = true;
                  };
                  runtimeInputs = [
                    pkgs.coreutils
                    pkgs.openssl
                  ];
                  script = ''
                    export LC_ALL=C
                    session_token="$(cat "$prompts/session-token")" || exit 1
                    case "$session_token" in
                      ""|*[!A-Za-z0-9._~+/=-]*)
                        echo "Tidal access token is missing or invalid" >&2
                        exit 1
                        ;;
                    esac
                    access_token="$(openssl rand -hex ${toString secretBytes})" || exit 1
                    printf '%s' "$access_token" > "$out/access-token"
                    {
                      printf 'TIDAL_SESSION_TOKEN=%s\n' "$session_token"
                      printf 'TIDAL_ENGINE_TOKEN=%s\n' "$access_token"
                    } > "$out/env-file"
                  '';
                };

                ${kagiGeneratorName} = lib.mkIf settings.enableKagi {
                  files = {
                    "env-file" = {
                      secret = true;
                      mode = "0400";
                    };
                    "access-token" = {
                      secret = true;
                      deploy = false;
                    };
                    "session-token".deploy = false;
                  };
                  prompts."session-token" = {
                    description = "Personal Kagi session token (token value only, never the complete Session Link)";
                    type = "hidden";
                    persist = true;
                  };
                  runtimeInputs = [
                    pkgs.coreutils
                    pkgs.openssl
                  ];
                  script = ''
                    export LC_ALL=C
                    session_token="$(cat "$prompts/session-token")" || exit 1
                    case "$session_token" in
                      ""|*[!A-Za-z0-9._~+/=-]*)
                        echo "Kagi session token is missing or invalid" >&2
                        exit 1
                        ;;
                    esac
                    access_token="$(openssl rand -hex ${toString secretBytes})" || exit 1
                    printf '%s' "$access_token" > "$out/access-token"
                    {
                      printf 'KAGI_SESSION_TOKEN=%s\n' "$session_token"
                      printf 'KAGI_ENGINE_TOKEN=%s\n' "$access_token"
                    } > "$out/env-file"
                  '';
                };

              };

              # Only the private runtime YAML renderer reads the account environment files.
              systemd.services.searx-init.serviceConfig.EnvironmentFile =
                lib.mkIf (settings.enableKagi || settings.enableTidal)
                  (
                    lib.mkForce (
                      [ config.services.searx.environmentFile ]
                      ++ lib.optional settings.enableKagi kagiEnvironmentFile
                      ++ lib.optional settings.enableTidal tidalEnvironmentFile
                    )
                  );

              networking.firewall.interfaces = lib.mkIf settings.openFirewall {
                ${settings.firewallInterface}.allowedTCPPorts = [ settings.port ];
              };
            }
            (import ./health.nix {
              inherit
                lib
                pkgs
                config
                settings
                kagiEnvironmentFile
                ;
            })
          ];
      };
  };
}
