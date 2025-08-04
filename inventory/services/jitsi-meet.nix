_: {
  instances = {
    # Jitsi Meet video conferencing service
    "jitsi-meet" = {
      module.name = "jitsi-meet";
      module.input = "self";
      roles.server = {
        tags."communication" = { };
        tags."web" = { };
        settings = {
          # Essential configuration
          domain = "meet.example.com";
          enableACME = true;

          # Authentication settings
          requireAuth = false;
          authType = "internal";

          # Features
          enableRecording = false;
          enableSIPGateway = false;
          enableWhiteboard = true;

          # Performance settings
          performanceProfile = "medium";
          maxParticipants = 50;

          # Customization
          brandingName = "Example Meet";
          defaultLanguage = "en";
          enableWelcomePage = true;
          requireDisplayName = true;

          # Additional configuration via freeform
          config = {
            # Enable prejoin page
            prejoinPageEnabled = true;

            # Audio/Video quality settings
            startAudioOnly = false;
            startWithAudioMuted = true;
            startWithVideoMuted = true;

            # Resolution constraints
            resolution = 720;
            constraints = {
              video = {
                height = {
                  ideal = 720;
                  max = 720;
                  min = 180;
                };
              };
            };

            # Recording settings (if enabled)
            fileRecordingsEnabled = true;
            liveStreamingEnabled = false;

            # Features toggles
            enableNoisyMicDetection = true;
            enableLipSync = false;
            enableRemb = true;
            enableTcc = true;

            # P2P settings
            p2p = {
              enabled = true;
              stunServers = [
                { urls = "stun:meet-jit-si-turnrelay.jitsi.net:3478"; }
              ];
            };
          };

          # Interface customization via freeform
          interfaceConfig = {
            SHOW_JITSI_WATERMARK = false;
            SHOW_WATERMARK_FOR_GUESTS = false;
            SHOW_BRAND_WATERMARK = false;
            BRAND_WATERMARK_LINK = "";

            DEFAULT_BACKGROUND = "#121212";
            DISABLE_VIDEO_BACKGROUND = false;

            TOOLBAR_BUTTONS = [
              "microphone"
              "camera"
              "closedcaptions"
              "desktop"
              "fullscreen"
              "fodeviceselection"
              "hangup"
              "profile"
              "chat"
              "recording"
              "livestreaming"
              "etherpad"
              "sharedvideo"
              "settings"
              "raisehand"
              "videoquality"
              "filmstrip"
              "invite"
              "feedback"
              "stats"
              "shortcuts"
              "tileview"
              "videobackgroundblur"
              "download"
              "help"
              "mute-everyone"
              "security"
            ];

            SETTINGS_SECTIONS = [
              "devices"
              "language"
              "moderator"
              "profile"
              "calendar"
            ];

            VIDEO_LAYOUT_FIT = "both";
            MOBILE_APP_PROMO = false;
            SHOW_CHROME_EXTENSION_BANNER = false;
          };

          # Prosody XMPP server settings via freeform
          prosody = {
            lockdown = true;
          };

          # Videobridge settings via freeform
          videobridge = {
            openFirewall = true;
            settings = {
              videobridge = {
                apis.rest.enabled = true;
                ice.tcp = {
                  enabled = true;
                  port = 4443;
                };
              };
            };
          };
        };
      };
    };
  };
}
