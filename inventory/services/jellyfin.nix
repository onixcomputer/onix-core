_: {
  instances = {

    "media-server" = {
      module.name = "jellyfin";
      module.input = "self";
      roles.server = {
        tags."media-server" = {
          # Example media library configuration
          # mediaLibraries = [
          #   {
          #     name = "Movies";
          #     type = "movies";
          #     paths = [ "/mnt/media/movies" ];
          #     language = "en";
          #     country = "US";
          #   }
          #   {
          #     name = "TV Shows";
          #     type = "tvshows";
          #     paths = [ "/mnt/media/tv" ];
          #     language = "en";
          #     country = "US";
          #   }
          # ];

          # Example transcoding configuration
          # transcoding = {
          #   hardwareAcceleration = "auto";  # auto-detect or: intel, nvidia, amd, vaapi, none
          #   enableHardwareDecoding = true;
          #   enableHardwareEncoding = true;
          #   enableToneMappingHardware = true;
          #   h264Crf = 23;  # Lower = better quality, larger files
          #   h265Crf = 25;
          #   maxConcurrentTranscodes = 2;
          #   # transcodingTempPath = "/tmp/jellyfin-transcode";
          # };

          # Example networking configuration
          # networking = {
          #   # DLNA/UPnP Configuration
          #   enableDlna = true;
          #   enableUpnp = true;
          #   dlnaServerName = "Home Media Server";
          #
          #   # Remote Access Configuration
          #   enableRemoteAccess = false;
          #   # publicHttpPort = 8096;
          #   # publicHttpsPort = 8920;
          #
          #   # Reverse Proxy Configuration (for nginx, traefik, etc.)
          #   behindReverseProxy = false;
          #   # knownProxies = [ "127.0.0.1" "10.0.0.0/8" ];
          #   # trustedProxies = [ "127.0.0.1" ];
          #
          #   # Bandwidth and Streaming Limits
          #   maxConcurrentStreams = 10;
          #   # globalStreamingBitrateLimit = 100000000;  # 100 Mbps
          #   throttleStreams = false;
          #
          #   # Cache Configuration
          #   imageCacheSize = 512;  # MB
          #   metadataCacheSize = 256;  # MB
          #   enableImageCaching = true;
          #   imageEnhancers = [ "BIF" "ChapterImageExtractor" ];
          #
          #   # Network Security
          #   localNetworkSubnets = [ "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "127.0.0.1" "::1" ];
          # };

          # Example user management configuration
          # userManagement = {
          #   # Create additional users automatically
          #   additionalUsers = [
          #     {
          #       username = "family";
          #       displayName = "Family Account";
          #       isAdministrator = false;
          #       maxParentalRating = "PG-13";
          #       enableContentDownloading = true;
          #       enableRemoteAccess = true;
          #       maxStreamingBitrate = 8000000;  # 8 Mbps
          #       blockedTags = [ "horror" "violence" ];
          #     }
          #     {
          #       username = "guest";
          #       displayName = "Guest User";
          #       isAdministrator = false;
          #       maxParentalRating = "PG";
          #       enableContentDownloading = false;
          #       enableRemoteAccess = false;
          #       maxStreamingBitrate = 4000000;  # 4 Mbps
          #       enabledLibraries = [ "Movies" "TV Shows" ];  # Only access specific libraries
          #       enableAudioPlaybackTranscoding = false;
          #       enableVideoPlaybackTranscoding = false;
          #     }
          #     {
          #       username = "admin2";
          #       displayName = "Secondary Admin";
          #       isAdministrator = true;
          #       enableContentDownloading = true;
          #       enableMediaConversion = true;
          #     }
          #   ];
          #
          #   # Authentication settings
          #   authenticationMethod = "local";  # or "ldap"
          #   requireStrongPasswords = true;
          #   passwordMinLength = 8;
          #   maxLoginAttemptsPerIp = 5;
          #   loginAttemptLockoutDuration = 300;  # 5 minutes
          #
          #   # LDAP configuration (when authenticationMethod = "ldap")
          #   # ldapSettings = {
          #   #   serverHost = "ldap.example.com";
          #   #   serverPort = 389;
          #   #   useSsl = false;
          #   #   baseDn = "ou=users,dc=example,dc=com";
          #   #   userFilter = "(uid={0})";
          #   #   adminFilter = "(memberOf=cn=jellyfin-admins,ou=groups,dc=example,dc=com)";
          #   #   bindUser = "cn=jellyfin,ou=service,dc=example,dc=com";
          #   #   bindPasswordFile = "/run/secrets/ldap-bind-password";
          #   # };
          #
          #   # OIDC/OAuth2 configuration (when authenticationMethod = "oidc")
          #   # oidcSettings = {
          #   #   providerName = "Keycloak";
          #   #   issuerUrl = "https://keycloak.company.com/realms/jellyfin";
          #   #   clientId = "jellyfin";
          #   #   clientSecretFile = "/run/secrets/oidc-client-secret";
          #   #
          #   #   # Claims mapping
          #   #   usernameClaim = "preferred_username";
          #   #   displayNameClaim = "name";
          #   #   emailClaim = "email";
          #   #   groupsClaim = "groups";
          #   #
          #   #   # Role/group mapping
          #   #   adminGroups = [ "jellyfin-admins" "media-admins" ];
          #   #   enabledGroups = [ "jellyfin-users" "media-users" ];  # Empty = all authenticated users
          #   #
          #   #   # Advanced settings
          #   #   scopes = [ "openid" "profile" "email" "groups" ];
          #   #   enableUserCreation = true;
          #   #   enableGroupSync = true;
          #   #   enableJwtValidation = true;
          #   #   clockSkewTolerance = 300;
          #   #
          #   #   # Provider-specific options
          #   #   additionalOptions = {
          #   #     pkce = true;
          #   #     response_mode = "query";
          #   #   };
          #   # };
          #
          #   # Plugin configuration
          #   # plugins = {
          #   #   # Enable official repository and common plugins
          #   #   enableOfficialRepository = true;
          #   #   enableCommonPlugins = true;  # Installs: OpenSubtitles, TMDb Box Sets, Reports, Fanart
          #   #
          #   #   # Additional repositories
          #   #   additionalRepositories = [
          #   #     {
          #   #       name = "Third Party";
          #   #       url = "https://raw.githubusercontent.com/jellyfin-contrib/jellyfin-plugin-repository/master/manifest.json";
          #   #       enabled = true;
          #   #     }
          #   #   ];
          #   #
          #   #   # Custom essential plugins (no API keys required)
          #   #   essentialPlugins = [
          #   #     # Add any additional plugins here
          #   #   ];
          #   #
          #   #   # Plugin update settings
          #   #   autoUpdatePlugins = true;
          #   #   updateCheckInterval = 24;  # hours
          #   # };
          # };
        };
      };
    };

  };
}
