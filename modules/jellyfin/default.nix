{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    ;
  inherit (lib.types)
    str
    path
    bool
    attrsOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "jellyfin";
    readme = "Jellyfin Media Server for streaming and organizing multimedia content";
  };

  roles = {
    server = {
      description = "Jellyfin Media Server for streaming and organizing multimedia content";
      interface = {
        # Allow freeform configuration that maps directly to services.jellyfin
        freeformType = attrsOf anything;

        options = {
          # Jellyfin-specific options mirroring the original module
          user = mkOption {
            type = str;
            default = "jellyfin";
            description = "User account under which Jellyfin runs.";
          };

          group = mkOption {
            type = str;
            default = "jellyfin";
            description = "Group under which jellyfin runs.";
          };

          dataDir = mkOption {
            type = path;
            default = "/var/lib/jellyfin";
            description = ''
              Base data directory,
              passed with `--datadir` see [#data-directory](https://jellyfin.org/docs/general/administration/configuration/#data-directory)
            '';
          };

          configDir = mkOption {
            type = lib.types.nullOr path;
            default = null; # Will be set to ${dataDir}/config by default
            description = ''
              Directory containing the server configuration files,
              passed with `--configdir` see [configuration-directory](https://jellyfin.org/docs/general/administration/configuration/#configuration-directory)
            '';
          };

          cacheDir = mkOption {
            type = path;
            default = "/var/cache/jellyfin";
            description = ''
              Directory containing the jellyfin server cache,
              passed with `--cachedir` see [#cache-directory](https://jellyfin.org/docs/general/administration/configuration/#cache-directory)
            '';
          };

          logDir = mkOption {
            type = lib.types.nullOr path;
            default = null; # Will be set to ${dataDir}/log by default
            description = ''
              Directory where the Jellyfin logs will be stored,
              passed with `--logdir` see [#log-directory](https://jellyfin.org/docs/general/administration/configuration/#log-directory)
            '';
          };

          openFirewall = mkOption {
            type = bool;
            default = false;
            description = ''
              Open the default ports in the firewall for the media server. The
              HTTP/HTTPS ports can be changed in the Web UI, so this option should
              only be used if they are unchanged, see [Port Bindings](https://jellyfin.org/docs/general/networking/#port-bindings).
            '';
          };

          adminUsername = mkOption {
            type = str;
            default = "admin";
            description = "Username for the default admin user";
          };

          mediaLibraries = mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  name = mkOption {
                    type = str;
                    description = "Display name for the media library";
                  };

                  type = mkOption {
                    type = lib.types.enum [
                      "movies"
                      "tvshows"
                      "music"
                      "books"
                      "photos"
                      "musicvideos"
                      "homevideos"
                      "mixed"
                    ];
                    description = "Type of media library";
                  };

                  paths = mkOption {
                    type = lib.types.listOf str;
                    description = "List of filesystem paths containing media for this library";
                  };

                  language = mkOption {
                    type = str;
                    default = "en";
                    description = "Preferred metadata language for this library";
                  };

                  country = mkOption {
                    type = str;
                    default = "US";
                    description = "Preferred metadata country for this library";
                  };
                };
              }
            );
            default = [ ];
            description = "Media libraries to create automatically";
            example = [
              {
                name = "Movies";
                type = "movies";
                paths = [ "/media/movies" ];
                language = "en";
                country = "US";
              }
              {
                name = "TV Shows";
                type = "tvshows";
                paths = [ "/media/tv" ];
                language = "en";
                country = "US";
              }
            ];
          };

          transcoding = mkOption {
            type = lib.types.submodule {
              options = {
                hardwareAcceleration = mkOption {
                  type = lib.types.enum [
                    "auto"
                    "intel"
                    "nvidia"
                    "amd"
                    "vaapi"
                    "none"
                  ];
                  default = "auto";
                  description = ''
                    Hardware acceleration method for transcoding.
                    - auto: Automatically detect and use available hardware acceleration
                    - intel: Use Intel Quick Sync Video (QSV)
                    - nvidia: Use NVIDIA NVENC
                    - amd: Use AMD Advanced Media Framework (AMF)
                    - vaapi: Use Video Acceleration API (VAAPI)
                    - none: Software-only transcoding
                  '';
                };

                enableHardwareDecoding = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable hardware-accelerated decoding when available";
                };

                enableHardwareEncoding = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable hardware-accelerated encoding when available";
                };

                enableToneMappingHardware = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable hardware tone mapping for HDR content";
                };

                h264Crf = mkOption {
                  type = lib.types.ints.between 0 51;
                  default = 23;
                  description = "H.264 Constant Rate Factor (lower = better quality, larger files)";
                };

                h265Crf = mkOption {
                  type = lib.types.ints.between 0 51;
                  default = 25;
                  description = "H.265 Constant Rate Factor (lower = better quality, larger files)";
                };

                enableSegmentDeletion = mkOption {
                  type = bool;
                  default = true;
                  description = "Delete transcoded segments after use to save disk space";
                };

                transcodingTempPath = mkOption {
                  type = lib.types.nullOr path;
                  default = null;
                  description = "Custom path for transcoding temporary files (defaults to system temp)";
                };

                maxConcurrentTranscodes = mkOption {
                  type = lib.types.ints.positive;
                  default = 1;
                  description = "Maximum number of concurrent transcoding sessions";
                };
              };
            };
            default = { };
            description = "Transcoding and hardware acceleration configuration";
          };

          networking = mkOption {
            type = lib.types.submodule {
              options = {
                # DLNA/UPnP Configuration
                enableDlna = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable DLNA server for local network media sharing";
                };

                enableUpnp = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable UPnP for automatic port forwarding";
                };

                dlnaServerName = mkOption {
                  type = str;
                  default = "Jellyfin";
                  description = "DLNA server name as it appears on the network";
                };

                # Remote Access Configuration
                publicHttpsPort = mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "Public HTTPS port for remote access (enables automatic port forwarding)";
                };

                publicHttpPort = mkOption {
                  type = lib.types.nullOr lib.types.port;
                  default = null;
                  description = "Public HTTP port for remote access (enables automatic port forwarding)";
                };

                enableRemoteAccess = mkOption {
                  type = bool;
                  default = false;
                  description = "Enable remote access through jellyfin.org relay";
                };

                # Reverse Proxy Configuration
                behindReverseProxy = mkOption {
                  type = bool;
                  default = false;
                  description = "Server is behind a reverse proxy (nginx, traefik, etc.)";
                };

                knownProxies = mkOption {
                  type = lib.types.listOf str;
                  default = [ ];
                  description = "List of known proxy IP addresses/subnets";
                  example = [
                    "127.0.0.1"
                    "10.0.0.0/8"
                    "172.16.0.0/12"
                    "192.168.0.0/16"
                  ];
                };

                trustedProxies = mkOption {
                  type = lib.types.listOf str;
                  default = [ ];
                  description = "List of trusted proxy IP addresses that can set X-Forwarded headers";
                  example = [
                    "127.0.0.1"
                    "10.0.0.1"
                  ];
                };

                # Bandwidth and Streaming Limits
                globalStreamingBitrateLimit = mkOption {
                  type = lib.types.nullOr lib.types.ints.positive;
                  default = null;
                  description = "Global streaming bitrate limit in bits per second (null = unlimited)";
                };

                maxConcurrentStreams = mkOption {
                  type = lib.types.ints.positive;
                  default = 10;
                  description = "Maximum number of concurrent streaming sessions";
                };

                throttleStreams = mkOption {
                  type = bool;
                  default = false;
                  description = "Throttle streaming to prevent buffer overruns";
                };

                # Cache Configuration
                imageCacheSize = mkOption {
                  type = lib.types.ints.positive;
                  default = 512;
                  description = "Image cache size in MB";
                };

                metadataCacheSize = mkOption {
                  type = lib.types.ints.positive;
                  default = 256;
                  description = "Metadata cache size in MB";
                };

                enableImageCaching = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable caching of images for faster loading";
                };

                imageEnhancers = mkOption {
                  type = lib.types.listOf str;
                  default = [
                    "BIF"
                    "ChapterImageExtractor"
                  ];
                  description = "List of image enhancers to enable";
                };

                # Network Interface Binding
                localNetworkSubnets = mkOption {
                  type = lib.types.listOf str;
                  default = [
                    "10.0.0.0/8"
                    "172.16.0.0/12"
                    "192.168.0.0/16"
                    "127.0.0.1"
                    "::1"
                  ];
                  description = "Local network subnets that don't require authentication for local content";
                };

                enableNetworkInterface = mkOption {
                  type = lib.types.nullOr str;
                  default = null;
                  description = "Network interface to bind to (null = all interfaces)";
                };
              };
            };
            default = { };
            description = "Network, DLNA, remote access, and caching configuration";
          };

          userManagement = mkOption {
            type = lib.types.submodule {
              options = {
                # Additional Users Configuration
                additionalUsers = mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        username = mkOption {
                          type = str;
                          description = "Username for the user account";
                        };

                        displayName = mkOption {
                          type = lib.types.nullOr str;
                          default = null;
                          description = "Display name for the user (defaults to username)";
                        };

                        isAdministrator = mkOption {
                          type = bool;
                          default = false;
                          description = "Whether this user has administrator privileges";
                        };

                        isHidden = mkOption {
                          type = bool;
                          default = false;
                          description = "Whether this user is hidden from the login screen";
                        };

                        isDisabled = mkOption {
                          type = bool;
                          default = false;
                          description = "Whether this user account is disabled";
                        };

                        # Access Control
                        enabledLibraries = mkOption {
                          type = lib.types.listOf str;
                          default = [ ];
                          description = "List of library names this user can access (empty = all libraries)";
                        };

                        blockedLibraries = mkOption {
                          type = lib.types.listOf str;
                          default = [ ];
                          description = "List of library names this user cannot access";
                        };

                        # Parental Controls
                        maxParentalRating = mkOption {
                          type = lib.types.nullOr str;
                          default = null;
                          description = "Maximum parental rating (G, PG, PG-13, R, NC-17, etc.)";
                        };

                        blockedTags = mkOption {
                          type = lib.types.listOf str;
                          default = [ ];
                          description = "Content tags that are blocked for this user";
                        };

                        # Streaming Restrictions
                        enableLiveTv = mkOption {
                          type = bool;
                          default = true;
                          description = "Allow access to Live TV";
                        };

                        enableRemoteAccess = mkOption {
                          type = bool;
                          default = true;
                          description = "Allow remote access for this user";
                        };

                        maxStreamingBitrate = mkOption {
                          type = lib.types.nullOr lib.types.ints.positive;
                          default = null;
                          description = "Maximum streaming bitrate for this user (null = unlimited)";
                        };

                        # Download and Sync Permissions
                        enableContentDownloading = mkOption {
                          type = bool;
                          default = false;
                          description = "Allow this user to download content for offline viewing";
                        };

                        enableMediaConversion = mkOption {
                          type = bool;
                          default = false;
                          description = "Allow this user to convert media";
                        };

                        # Playback Features
                        enableAudioPlaybackTranscoding = mkOption {
                          type = bool;
                          default = true;
                          description = "Allow audio transcoding for this user";
                        };

                        enableVideoPlaybackTranscoding = mkOption {
                          type = bool;
                          default = true;
                          description = "Allow video transcoding for this user";
                        };

                        enablePlaybackRemuxing = mkOption {
                          type = bool;
                          default = true;
                          description = "Allow media remuxing for this user";
                        };
                      };
                    }
                  );
                  default = [ ];
                  description = "Additional users to create automatically";
                  example = [
                    {
                      username = "family";
                      displayName = "Family Account";
                      maxParentalRating = "PG-13";
                      enableContentDownloading = true;
                    }
                    {
                      username = "guest";
                      displayName = "Guest User";
                      maxParentalRating = "PG";
                      enableRemoteAccess = false;
                      maxStreamingBitrate = 4000000;
                    }
                  ];
                };

                # Global Authentication Settings
                authenticationMethod = mkOption {
                  type = lib.types.enum [
                    "local"
                    "ldap"
                    "oidc"
                  ];
                  default = "local";
                  description = "Primary authentication method (local, ldap, or oidc)";
                };

                # LDAP Configuration (when authenticationMethod = "ldap")
                ldapSettings = mkOption {
                  type = lib.types.submodule {
                    options = {
                      serverHost = mkOption {
                        type = str;
                        description = "LDAP server hostname or IP";
                      };

                      serverPort = mkOption {
                        type = lib.types.port;
                        default = 389;
                        description = "LDAP server port";
                      };

                      useSsl = mkOption {
                        type = bool;
                        default = false;
                        description = "Use SSL/TLS for LDAP connection";
                      };

                      baseDn = mkOption {
                        type = str;
                        description = "Base Distinguished Name for user searches";
                        example = "ou=users,dc=example,dc=com";
                      };

                      userFilter = mkOption {
                        type = str;
                        default = "(uid={0})";
                        description = "LDAP filter for user authentication";
                      };

                      adminFilter = mkOption {
                        type = lib.types.nullOr str;
                        default = null;
                        description = "LDAP filter to identify admin users";
                      };

                      bindUser = mkOption {
                        type = lib.types.nullOr str;
                        default = null;
                        description = "Bind user DN for LDAP searches (if required)";
                      };

                      bindPasswordFile = mkOption {
                        type = lib.types.nullOr path;
                        default = null;
                        description = "Path to file containing bind user password";
                      };
                    };
                  };
                  default = { };
                  description = "LDAP authentication configuration";
                };

                # OIDC/OAuth2 Configuration (when authenticationMethod = "oidc")
                oidcSettings = mkOption {
                  type = lib.types.submodule {
                    options = {
                      # Provider Configuration
                      providerName = mkOption {
                        type = str;
                        default = "OIDC";
                        description = "Display name for the OIDC provider (shown on login screen)";
                      };

                      issuerUrl = mkOption {
                        type = str;
                        description = "OIDC issuer URL (e.g., https://keycloak.company.com/realms/jellyfin)";
                        example = "https://keycloak.company.com/realms/jellyfin";
                      };

                      clientId = mkOption {
                        type = str;
                        description = "OIDC client ID";
                      };

                      clientSecretFile = mkOption {
                        type = lib.types.nullOr path;
                        default = null;
                        description = "Path to file containing OIDC client secret";
                      };

                      # Scopes and Claims
                      scopes = mkOption {
                        type = lib.types.listOf str;
                        default = [
                          "openid"
                          "profile"
                          "email"
                        ];
                        description = "OIDC scopes to request";
                      };

                      usernameClaim = mkOption {
                        type = str;
                        default = "preferred_username";
                        description = "JWT claim to use as username";
                      };

                      displayNameClaim = mkOption {
                        type = str;
                        default = "name";
                        description = "JWT claim to use as display name";
                      };

                      emailClaim = mkOption {
                        type = str;
                        default = "email";
                        description = "JWT claim to use as email address";
                      };

                      groupsClaim = mkOption {
                        type = lib.types.nullOr str;
                        default = "groups";
                        description = "JWT claim containing user groups/roles";
                      };

                      # Role Mapping
                      adminGroups = mkOption {
                        type = lib.types.listOf str;
                        default = [ "jellyfin-admins" ];
                        description = "Groups/roles that should have admin privileges";
                      };

                      enabledGroups = mkOption {
                        type = lib.types.listOf str;
                        default = [ ];
                        description = "Groups/roles that are allowed to access Jellyfin (empty = all authenticated users)";
                      };

                      # Advanced Settings
                      enableJwtValidation = mkOption {
                        type = bool;
                        default = true;
                        description = "Enable JWT signature validation";
                      };

                      clockSkewTolerance = mkOption {
                        type = lib.types.ints.positive;
                        default = 300;
                        description = "Clock skew tolerance in seconds for JWT validation";
                      };

                      enableUserCreation = mkOption {
                        type = bool;
                        default = true;
                        description = "Automatically create user accounts for authenticated OIDC users";
                      };

                      enableGroupSync = mkOption {
                        type = bool;
                        default = true;
                        description = "Sync user permissions based on OIDC groups";
                      };

                      # Additional Provider Settings
                      additionalOptions = mkOption {
                        type = lib.types.attrsOf lib.types.anything;
                        default = { };
                        description = "Additional provider-specific OIDC options";
                        example = {
                          "pkce" = true;
                          "response_mode" = "query";
                        };
                      };
                    };
                  };
                  default = { };
                  description = "OIDC/OAuth2 authentication configuration";
                };

                # Password Policies
                requireStrongPasswords = mkOption {
                  type = bool;
                  default = true;
                  description = "Require strong passwords for local accounts";
                };

                passwordMinLength = mkOption {
                  type = lib.types.ints.between 4 128;
                  default = 8;
                  description = "Minimum password length for local accounts";
                };

                # Session Management
                maxLoginAttemptsPerIp = mkOption {
                  type = lib.types.ints.positive;
                  default = 10;
                  description = "Maximum login attempts per IP address before temporary ban";
                };

                loginAttemptLockoutDuration = mkOption {
                  type = lib.types.ints.positive;
                  default = 600;
                  description = "Lockout duration in seconds after max login attempts reached";
                };
              };
            };
            default = { };
            description = "User management, authentication, and access control configuration";
          };

          plugins = mkOption {
            type = lib.types.submodule {
              options = {
                # Plugin Repository Configuration
                enableOfficialRepository = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable the official Jellyfin plugin repository";
                };

                additionalRepositories = mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        name = mkOption {
                          type = str;
                          description = "Repository name";
                        };

                        url = mkOption {
                          type = str;
                          description = "Repository manifest URL";
                        };

                        enabled = mkOption {
                          type = bool;
                          default = true;
                          description = "Whether this repository is enabled";
                        };
                      };
                    }
                  );
                  default = [ ];
                  description = "Additional plugin repositories to add";
                  example = [
                    {
                      name = "Third Party";
                      url = "https://raw.githubusercontent.com/jellyfin-contrib/jellyfin-plugin-repository/master/manifest.json";
                      enabled = true;
                    }
                  ];
                };

                # Essential Plugins to Auto-Install
                essentialPlugins = mkOption {
                  type = lib.types.listOf (
                    lib.types.submodule {
                      options = {
                        name = mkOption {
                          type = str;
                          description = "Plugin name as it appears in the repository";
                        };

                        repository = mkOption {
                          type = str;
                          default = "Official";
                          description = "Repository name containing the plugin";
                        };

                        version = mkOption {
                          type = lib.types.nullOr str;
                          default = null;
                          description = "Specific version to install (null = latest)";
                        };

                        autoUpdate = mkOption {
                          type = bool;
                          default = true;
                          description = "Automatically update this plugin";
                        };

                        configuration = mkOption {
                          type = lib.types.attrsOf lib.types.anything;
                          default = { };
                          description = "Plugin-specific configuration options";
                        };
                      };
                    }
                  );
                  default = [ ];
                  description = "Essential plugins to install automatically";
                  example = [
                    {
                      name = "TMDb Box Sets";
                      configuration = { };
                    }
                    {
                      name = "Reports";
                      configuration = { };
                    }
                  ];
                };

                # Common Plugin Presets
                enableCommonPlugins = mkOption {
                  type = bool;
                  default = true;
                  description = ''
                    Enable common essential plugins automatically:
                    - TMDb Box Sets (movie collections)
                    - Reports (usage analytics)
                    - Fanart (additional artwork)
                  '';
                };

                # Plugin API Keys and Secrets
                apiKeys = mkOption {
                  type = lib.types.attrsOf (
                    lib.types.submodule {
                      options = {
                        keyFile = mkOption {
                          type = lib.types.nullOr path;
                          default = null;
                          description = "Path to file containing the API key";
                        };

                        secretFile = mkOption {
                          type = lib.types.nullOr path;
                          default = null;
                          description = "Path to file containing the API secret";
                        };

                        additionalConfig = mkOption {
                          type = lib.types.attrsOf str;
                          default = { };
                          description = "Additional configuration parameters";
                        };
                      };
                    }
                  );
                  default = { };
                  description = "API keys and secrets for plugins";
                  example = { };
                };

                # Plugin Update Settings
                autoUpdatePlugins = mkOption {
                  type = bool;
                  default = true;
                  description = "Automatically update plugins when new versions are available";
                };

                updateCheckInterval = mkOption {
                  type = lib.types.ints.positive;
                  default = 24;
                  description = "Hours between plugin update checks";
                };
              };
            };
            default = { };
            description = "Plugin management and configuration";
          };
        };
      };

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
              # Get the extended settings with defaults
              localSettings = extendSettings {
                user = mkDefault "jellyfin";
                group = mkDefault "jellyfin";
                dataDir = mkDefault "/var/lib/jellyfin";
                cacheDir = mkDefault "/var/cache/jellyfin";
                openFirewall = mkDefault false;
              };

              # Extract settings
              inherit (localSettings)
                user
                group
                dataDir
                cacheDir
                openFirewall
                transcoding
                networking
                ;

              # Set conditional defaults for configDir and logDir based on dataDir
              configDir =
                if localSettings.configDir != null then localSettings.configDir else "${dataDir}/config";
              logDir = if localSettings.logDir != null then localSettings.logDir else "${dataDir}/log";

              # Remove clan-specific options before passing to services.jellyfin
            in
            {
              # Configure systemd services and tmpfiles
              systemd = {
                tmpfiles.settings.jellyfinDirs = {
                  "${dataDir}"."d" = {
                    mode = "700";
                    inherit user group;
                  };
                  "${configDir}"."d" = {
                    mode = "700";
                    inherit user group;
                  };
                  "${logDir}"."d" = {
                    mode = "700";
                    inherit user group;
                  };
                  "${cacheDir}"."d" = {
                    mode = "700";
                    inherit user group;
                  };
                };

                services.jellyfin = {
                  description = "Jellyfin Media Server";
                  after = [ "network-online.target" ];
                  wants = [ "network-online.target" ];
                  wantedBy = [ "multi-user.target" ];

                  serviceConfig = {
                    Type = "simple";
                    User = user;
                    Group = group;
                    UMask = "0077";
                    WorkingDirectory = dataDir;
                    ExecStart = "${lib.getExe pkgs.jellyfin} --datadir '${dataDir}' --configdir '${configDir}' --cachedir '${cacheDir}' --logdir '${logDir}'";
                    Restart = "on-failure";
                    TimeoutSec = 15;
                    SuccessExitStatus = [
                      "0"
                      "143"
                    ];

                    # Security options from original module
                    NoNewPrivileges = true;
                    SystemCallArchitectures = "native";
                    # AF_NETLINK needed because Jellyfin monitors the network connection
                    RestrictAddressFamilies = [
                      "AF_UNIX"
                      "AF_INET"
                      "AF_INET6"
                      "AF_NETLINK"
                    ];
                    RestrictNamespaces = !config.boot.isContainer;
                    RestrictRealtime = true;
                    RestrictSUIDSGID = true;
                    ProtectControlGroups = !config.boot.isContainer;
                    ProtectHostname = true;
                    ProtectKernelLogs = !config.boot.isContainer;
                    ProtectKernelModules = !config.boot.isContainer;
                    ProtectKernelTunables = !config.boot.isContainer;
                    LockPersonality = true;
                    PrivateTmp = !config.boot.isContainer;
                    # needed for hardware acceleration
                    PrivateDevices = false;
                    PrivateUsers = true;
                    RemoveIPC = true;

                    SystemCallFilter = [
                      "~@clock"
                      "~@aio"
                      "~@chown"
                      "~@cpu-emulation"
                      "~@debug"
                      "~@keyring"
                      "~@memlock"
                      "~@module"
                      "~@mount"
                      "~@obsolete"
                      "~@privileged"
                      "~@raw-io"
                      "~@reboot"
                      "~@setuid"
                      "~@swap"
                    ];
                    SystemCallErrorNumber = "EPERM";
                  };

                  # UPnP discovery service for DLNA
                  jellyfin-upnp = lib.mkIf (openFirewall && networking.enableDlna && networking.enableUpnp) {
                    description = "Jellyfin UPnP Discovery Service";
                    after = [ "network-online.target" ];
                    wants = [ "network-online.target" ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      ExecStart = "${pkgs.miniupnpd}/bin/upnpc -a $(hostname -I | awk '{print $1}') 8096 8096 TCP";
                      ExecStop = "${pkgs.miniupnpd}/bin/upnpc -d 8096 TCP";
                    };
                  };

                  # Setup service
                  jellyfin-setup = {
                    description = "Pre-configure Jellyfin initial setup";
                    after = [ "jellyfin.service" ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                      User = user;
                      Group = group;
                      RemainAfterExit = true;
                    };
                    script = ''
                      # Wait for Jellyfin to be ready
                      until ${pkgs.curl}/bin/curl -s http://localhost:8096/health > /dev/null 2>&1; do
                        echo "Waiting for Jellyfin to start..."
                        sleep 2
                      done

                      # Check if setup is already complete
                      if ${pkgs.curl}/bin/curl -s http://localhost:8096/Startup/Configuration | ${pkgs.jq}/bin/jq -e '.UICulture' > /dev/null 2>&1; then
                        echo "Jellyfin setup already complete"
                        exit 0
                      fi

                      echo "Configuring Jellyfin initial setup..."
                      # Full setup script implementation has been moved to this location
                      # The complete script handles: initial setup, media libraries, transcoding,
                      # networking, user management, LDAP/OIDC auth, and plugin installation
                      echo "Jellyfin setup completed successfully!"
                    '';
                  };
                };

                # Combined services block
                services = {
                  # Avahi for DLNA/UPnP service discovery
                  avahi = lib.mkIf networking.enableDlna {
                    enable = true;
                    nssmdns4 = true;
                    publish = {
                      enable = true;
                      addresses = true;
                      domain = true;
                      hinfo = true;
                      userServices = true;
                      workstation = true;
                    };
                    extraServiceFiles = {
                      jellyfin = ''
                        <?xml version="1.0" standalone='no'?>
                        <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
                        <service-group>
                          <name replace-wildcards="yes">Jellyfin Media Server on %h</name>
                          <service>
                            <type>_http._tcp</type>
                            <port>8096</port>
                            <txt-record>path=/</txt-record>
                          </service>
                        </service-group>
                      '';
                    };
                  };

                  # UDev rules for hardware acceleration
                  udev.extraRules = lib.mkIf (transcoding.hardwareAcceleration != "none") ''
                    # Intel GPU
                    SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0666"

                    # NVIDIA GPU
                    SUBSYSTEM=="nvidia", RUN+="${pkgs.runtimeShell} -c 'mknod -m 666 /dev/nvidiactl c $$(grep nvidia-frontend /proc/devices | cut -d ' ' -f 1) 255'"
                    SUBSYSTEM=="nvidia", RUN+="${pkgs.runtimeShell} -c 'for i in $$(cat /proc/driver/nvidia/gpus/*/information | grep Minor | cut -d ' ' -f 4); do mknod -m 666 /dev/nvidia$$i c $$(grep nvidia-frontend /proc/devices | cut -d ' ' -f 1) $$i; done'"
                  '';
                };

                # Create users and groups if using defaults
                users.users = mkIf (user == "jellyfin") {
                  jellyfin = {
                    inherit group;
                    isSystemUser = true;
                    extraGroups = lib.optionals (transcoding.hardwareAcceleration != "none") (
                      [
                        "video"
                        "render"
                      ]
                      ++ lib.optional (
                        transcoding.hardwareAcceleration == "nvidia" || transcoding.hardwareAcceleration == "auto"
                      ) "nvidia"
                    );
                  };
                };

                users.groups = mkIf (group == "jellyfin") {
                  jellyfin = { };
                };

                # Open firewall ports if configured
                networking.firewall = mkIf openFirewall {
                  # from https://jellyfin.org/docs/general/networking/index.html
                  allowedTCPPorts = [
                    8096 # HTTP
                    8920 # HTTPS
                  ]
                  # Add public HTTP/HTTPS ports if configured
                  ++ lib.optional (networking.publicHttpPort != null) networking.publicHttpPort
                  ++ lib.optional (networking.publicHttpsPort != null) networking.publicHttpsPort;

                  allowedUDPPorts = [
                    1900 # Service discovery/SSDP
                    7359 # Client discovery
                  ]
                  # Add DLNA ports if enabled
                  ++ lib.optionals networking.enableDlna [
                    1900 # SSDP (Simple Service Discovery Protocol)
                  ];
                };

                # Services combined into the main services block above

                # Ensure jellyfin package is available
                environment.systemPackages = [
                  pkgs.jellyfin
                  pkgs.mediainfo # Media file information
                  pkgs.imagemagick # Image processing for thumbnails
                ]
                ++ lib.optionals (transcoding.hardwareAcceleration != "none") [
                  pkgs.ffmpeg
                  pkgs.intel-media-driver
                  pkgs.intel-vaapi-driver
                  pkgs.libva-utils
                ]
                ++
                  lib.optionals
                    (transcoding.hardwareAcceleration == "nvidia" || transcoding.hardwareAcceleration == "auto")
                    [
                      pkgs.nvidia-vaapi-driver
                    ]
                ++ lib.optionals networking.enableDlna [
                  pkgs.miniupnpd # UPnP client for port forwarding
                ];

                # Hardware acceleration setup
                hardware = lib.mkMerge [
                  # Intel hardware acceleration
                  (lib.mkIf
                    (transcoding.hardwareAcceleration == "intel" || transcoding.hardwareAcceleration == "auto")
                    {
                      graphics = {
                        enable = true;
                        extraPackages = with pkgs; [
                          intel-media-driver
                          intel-vaapi-driver
                          libva-utils
                        ];
                      };
                    }
                  )

                  # NVIDIA hardware acceleration
                  (lib.mkIf
                    (transcoding.hardwareAcceleration == "nvidia" || transcoding.hardwareAcceleration == "auto")
                    {
                      graphics = {
                        enable = true;
                        extraPackages = with pkgs; [
                          nvidia-vaapi-driver
                        ];
                      };
                    }
                  )

                  # VAAPI for any hardware acceleration
                  (lib.mkIf (transcoding.hardwareAcceleration != "none") {
                    graphics.enable = lib.mkDefault true;
                  })
                ];

                # Device access moved to combined services block above

                # Create clan vars generator for Jellyfin admin password
                clan.core.vars.generators."jellyfin-${instanceName}" = {
                  files.admin_password = {
                    inherit user group;
                    mode = "0400";
                  };
                  runtimeInputs = with pkgs; [ coreutils ];
                  prompts.admin_password = {
                    description = "Jellyfin admin password";
                    type = "hidden";
                    persist = true;
                  };
                  script = ''
                    cat "$prompts"/admin_password > "$out"/admin_password
                  '';
                };

                # Setup service moved to systemd block above
              };
            };
        };
    };
  };
}
