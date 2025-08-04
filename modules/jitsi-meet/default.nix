{ lib, ... }:
let
  inherit (lib) mkOption mkDefault mkIf;
  inherit (lib.types)
    bool
    str
    nullOr
    int
    attrsOf
    anything
    enum
    ;
in
{
  _class = "clan.service";
  manifest.name = "jitsi-meet";

  roles = {
    server = {
      interface = {
        # Freeform type allows any services.jitsi-meet option
        freeformType = attrsOf anything;

        options = {
          # Essential clan conveniences
          domain = mkOption {
            type = str;
            description = "Domain name for the Jitsi Meet instance";
            example = "meet.example.com";
          };

          enableACME = mkOption {
            type = bool;
            default = true;
            description = "Enable automatic HTTPS certificate via ACME";
          };

          # Authentication
          requireAuth = mkOption {
            type = bool;
            default = false;
            description = "Require authentication to create rooms";
          };

          authType = mkOption {
            type = enum [
              "internal"
              "jwt"
              "ldap"
            ];
            default = "internal";
            description = "Authentication type to use";
          };

          # Features
          enableRecording = mkOption {
            type = bool;
            default = false;
            description = "Enable Jibri recording service";
          };

          enableSIPGateway = mkOption {
            type = bool;
            default = false;
            description = "Enable Jigasi SIP gateway for phone dial-in";
          };

          enableWhiteboard = mkOption {
            type = bool;
            default = false;
            description = "Enable Excalidraw whiteboard integration";
          };

          # Performance
          performanceProfile = mkOption {
            type = enum [
              "small"
              "medium"
              "large"
            ];
            default = "medium";
            description = ''
              Performance profile:
              - small: Up to 10 participants
              - medium: Up to 50 participants
              - large: 100+ participants
            '';
          };

          maxParticipants = mkOption {
            type = nullOr int;
            default = null;
            description = "Maximum number of participants per room (null for unlimited)";
          };

          # Customization
          brandingName = mkOption {
            type = nullOr str;
            default = null;
            description = "Custom branding name for the instance";
          };

          defaultLanguage = mkOption {
            type = str;
            default = "en";
            description = "Default language for the interface";
          };

          enableWelcomePage = mkOption {
            type = bool;
            default = true;
            description = "Show welcome page";
          };

          requireDisplayName = mkOption {
            type = bool;
            default = false;
            description = "Require users to enter display name before joining";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                domain
                enableACME
                requireAuth
                authType
                enableRecording
                enableSIPGateway
                enableWhiteboard
                performanceProfile
                maxParticipants
                brandingName
                defaultLanguage
                enableWelcomePage
                requireDisplayName
                ;

              # Remove clan options from freeform config
              jitsiConfig = builtins.removeAttrs settings [
                "domain"
                "enableACME"
                "requireAuth"
                "authType"
                "enableRecording"
                "enableSIPGateway"
                "enableWhiteboard"
                "performanceProfile"
                "maxParticipants"
                "brandingName"
                "defaultLanguage"
                "enableWelcomePage"
                "requireDisplayName"
              ];

              # Performance profiles
              performanceSettings = {
                small = {
                  config = {
                    channelLastN = 4;
                    enableLayerSuspension = true;
                    disableAudioLevels = true;
                  };
                  videobridge.settings.videobridge.low-port = 10000;
                  videobridge.settings.videobridge.high-port = 10010;
                };
                medium = {
                  config = {
                    channelLastN = 12;
                    enableLayerSuspension = true;
                    disableAudioLevels = false;
                  };
                  videobridge.settings.videobridge.low-port = 10000;
                  videobridge.settings.videobridge.high-port = 10050;
                };
                large = {
                  config = {
                    channelLastN = 25;
                    enableLayerSuspension = false;
                    disableAudioLevels = false;
                  };
                  videobridge.settings.videobridge.low-port = 10000;
                  videobridge.settings.videobridge.high-port = 10200;
                };
              };

            in
            {
              # Core Jitsi Meet configuration
              services.jitsi-meet = lib.mkMerge [
                {
                  enable = true;
                  hostName = domain;

                  # Secure domain configuration
                  secureDomain = {
                    enable = requireAuth;
                    authentication = authType;
                  };

                  # Basic configuration with clan defaults
                  config = {
                    defaultLang = defaultLanguage;
                    inherit enableWelcomePage requireDisplayName;
                    prejoinPageEnabled = mkDefault true;
                  };

                  # Interface customization
                  interfaceConfig = {
                    SHOW_JITSI_WATERMARK = mkDefault false;
                    SHOW_WATERMARK_FOR_GUESTS = mkDefault false;
                    DISABLE_TRANSCRIPTION_SUBTITLES = mkDefault false;
                  };
                }

                # Apply performance profile
                (performanceSettings.${performanceProfile} or { })

                # Apply branding if specified
                (mkIf (brandingName != null) {
                  interfaceConfig.APP_NAME = brandingName;
                  config.brandingDataUrl = "";
                })

                # Apply max participants limit
                (mkIf (maxParticipants != null) {
                  config.maxParticipants = maxParticipants;
                })

                # Apply freeform configuration last to allow overrides
                jitsiConfig
              ];

              # Services configuration
              services = {
                # Nginx configuration with ACME
                nginx = mkIf config.services.jitsi-meet.nginx.enable {
                  virtualHosts.${domain} = {
                    inherit enableACME;
                    forceSSL = enableACME;
                  };
                };

                # Jibri recording service
                jibri = mkIf enableRecording {
                  enable = true;
                  withChromium = true;
                  config = {
                    recording.recordings-directory = "/var/lib/jibri/recordings";
                    api.xmpp.environments = [
                      {
                        name = "jitsi-meet";
                        xmpp-server-hosts = [ "localhost" ];
                        xmpp-domain = domain;
                        control-muc = {
                          domain = "internal.${domain}";
                          room-name = "JibriBrewery";
                          nickname = "jibri";
                        };
                        control-login = {
                          domain = "auth.${domain}";
                          username = "jibri";
                          password-file = config.clan.core.vars.generators.jitsi-meet-jibri.files.auth_secret.path;
                        };
                        call-login = {
                          domain = "recorder.${domain}";
                          username = "recorder";
                          password-file = config.clan.core.vars.generators.jitsi-meet-jibri.files.recorder_secret.path;
                        };
                      }
                    ];
                  };
                };

                # Jigasi SIP gateway
                jigasi = mkIf enableSIPGateway {
                  enable = true;
                  xmppDomain = domain;
                  xmppServerHost = "localhost";
                  componentPasswordFile =
                    config.clan.core.vars.generators.jitsi-meet-jigasi.files.component_secret.path;
                  userPasswordFile = config.clan.core.vars.generators.jitsi-meet-jigasi.files.user_secret.path;
                };

                # Excalidraw whiteboard
                excalidraw = mkIf enableWhiteboard {
                  enable = true;
                  port = 3005;
                };
              };

              # Firewall rules
              networking.firewall = {
                allowedTCPPorts = [
                  80
                  443
                ];
                allowedUDPPortRanges = mkIf (performanceSettings.${performanceProfile} ? videobridge) [
                  {
                    from = performanceSettings.${performanceProfile}.videobridge.settings.videobridge.low-port;
                    to = performanceSettings.${performanceProfile}.videobridge.settings.videobridge.high-port;
                  }
                ];
              };

              # Ensure required users exist
              users.users = mkIf enableRecording {
                jibri.extraGroups = [
                  "video"
                  "audio"
                ];
              };
            };
        };
    };
  };

  # Common configuration for all machines
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Clan vars generators
        clan.core.vars.generators = {
          # Core Jitsi Meet secrets generator
          jitsi-meet = {
            files = {
              jicofo-component-secret = { };
              jicofo-user-secret = { };
              videobridge-secret = { };
            };
            runtimeInputs = with pkgs; [ coreutils ];
            script = ''
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/jicofo-component-secret"
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/jicofo-user-secret"
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/videobridge-secret"
            '';
          };

          # Jibri secrets generator (if recording is enabled)
          jitsi-meet-jibri = {
            files = {
              auth_secret = { };
              recorder_secret = { };
            };
            runtimeInputs = with pkgs; [ coreutils ];
            script = ''
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/auth_secret"
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/recorder_secret"
            '';
          };

          # Jigasi secrets generator (if SIP gateway is enabled)
          jitsi-meet-jigasi = {
            files = {
              component_secret = { };
              user_secret = { };
            };
            runtimeInputs = with pkgs; [ coreutils ];
            script = ''
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/component_secret"
              tr -dc a-zA-Z0-9 < /dev/urandom | head -c 64 > "$out/user_secret"
            '';
          };
        };
      };
  };
}
