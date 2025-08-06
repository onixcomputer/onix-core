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
    listOf
    ;
in
{
  _class = "clan.service";
  manifest.name = "seaweedfs";

  roles = {
    server = {
      interface = {
        # Allow freeform configuration that maps directly to seaweedfs services
        freeformType = attrsOf anything;

        options = {
          # Clan-specific options
          mode = mkOption {
            type = enum [
              "master"
              "volume"
              "filer"
              "all"
            ];
            default = "all";
            description = ''
              SeaweedFS operation mode:
              - master: Run only master server
              - volume: Run only volume server
              - filer: Run only filer server
              - all: Run all components
            '';
          };

          masterDomain = mkOption {
            type = nullOr str;
            default = null;
            description = "Domain name for the master server (enables nginx reverse proxy)";
            example = "seaweed-master.example.com";
          };

          filerDomain = mkOption {
            type = nullOr str;
            default = null;
            description = "Domain name for the filer server (enables nginx reverse proxy)";
            example = "seaweed.example.com";
          };

          enableSSL = mkOption {
            type = bool;
            default = true;
            description = "Enable SSL/TLS with ACME certificates when domain is set";
          };

          replication = mkOption {
            type = str;
            default = "000";
            description = ''
              Replication strategy in format xyz where:
              x = number of replicas on different data centers
              y = number of replicas on different racks in same data center
              z = number of replicas on different servers in same rack
            '';
            example = "001";
          };

          volumeSize = mkOption {
            type = int;
            default = 30000;
            description = "Maximum volume size in MB";
          };

          dataCenter = mkOption {
            type = nullOr str;
            default = null;
            description = "Data center name for rack-aware replication";
          };

          rack = mkOption {
            type = nullOr str;
            default = null;
            description = "Rack name for rack-aware replication";
          };

          masterServers = mkOption {
            type = listOf str;
            default = [ "localhost:9333" ];
            description = "List of master servers (for volume/filer nodes)";
            example = [
              "master1.example.com:9333"
              "master2.example.com:9333"
            ];
          };

          auth = {
            enable = mkOption {
              type = bool;
              default = false;
              description = "Enable authentication";
            };

            adminUsername = mkOption {
              type = str;
              default = "admin";
              description = "Admin username for authentication";
            };
          };

          s3 = {
            enable = mkOption {
              type = bool;
              default = false;
              description = "Enable S3 API compatibility";
            };

            port = mkOption {
              type = int;
              default = 8333;
              description = "S3 API port";
            };

            domain = mkOption {
              type = nullOr str;
              default = null;
              description = "Domain name for S3 API (enables nginx reverse proxy)";
              example = "s3.example.com";
            };
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              # Get the extended settings
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                mode
                masterDomain
                filerDomain
                enableSSL
                replication
                volumeSize
                dataCenter
                rack
                masterServers
                ;
              auth = settings.auth or { };
              authEnabled = auth.enable or false;
              adminUsername = auth.adminUsername or "admin";
              s3Config = settings.s3 or { };
              s3Enabled = s3Config.enable or false;
              s3Port = s3Config.port or 8333;
              s3Domain = s3Config.domain or null;

              # Get secret paths from clan vars
              adminPasswordFile =
                if authEnabled then
                  config.clan.core.vars.generators.seaweedfs-auth.files.admin_password.path
                else
                  null;
              jwtSigningKeyFile =
                if authEnabled then
                  config.clan.core.vars.generators.seaweedfs-auth.files.jwt_signing_key.path
                else
                  null;

              # Helper to determine which components to run
              runMaster = mode == "master" || mode == "all";
              runVolume = mode == "volume" || mode == "all";
              runFiler = mode == "filer" || mode == "all";

              # Master servers list for volume/filer nodes
              masterServersList =
                if runMaster && (mode == "all" || mode == "master") then [ "localhost:9333" ] else masterServers;

            in
            {
              # SeaweedFS systemd services
              systemd.services = lib.mkMerge [
                # Master server
                (mkIf runMaster {
                  seaweedfs-master = {
                    description = "SeaweedFS Master Server";
                    after = [ "network.target" ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "simple";
                      DynamicUser = true;
                      StateDirectory = "seaweedfs-master";
                      RuntimeDirectory = "seaweedfs-master";
                      ExecStart = ''
                        ${pkgs.seaweedfs}/bin/weed master \
                          -ip=${if masterDomain != null then "0.0.0.0" else "127.0.0.1"} \
                          -port=9333 \
                          -mdir=/var/lib/seaweedfs-master \
                          -defaultReplication=${replication} \
                          -volumeSizeLimitMB=${toString volumeSize} \
                          ${lib.optionalString authEnabled "-auth.jwt.signing.key=$(cat ${jwtSigningKeyFile})"} \
                          ${lib.optionalString (dataCenter != null) "-dataCenter=${dataCenter}"} \
                          ${lib.optionalString (rack != null) "-rack=${rack}"}
                      '';
                      Restart = "on-failure";
                      RestartSec = "5s";

                      # Load credentials if auth is enabled
                      LoadCredential = lib.optionals authEnabled [
                        "admin_password:${adminPasswordFile}"
                        "jwt_signing_key:${jwtSigningKeyFile}"
                      ];
                    };
                  };
                })

                # Volume server
                (mkIf runVolume {
                  seaweedfs-volume = {
                    description = "SeaweedFS Volume Server";
                    after = [ "network.target" ] ++ lib.optional runMaster "seaweedfs-master.service";
                    wants = lib.optional runMaster "seaweedfs-master.service";
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "simple";
                      DynamicUser = true;
                      StateDirectory = "seaweedfs-volume";
                      RuntimeDirectory = "seaweedfs-volume";
                      ExecStart = ''
                        ${pkgs.seaweedfs}/bin/weed volume \
                          -ip=0.0.0.0 \
                          -port=8080 \
                          -dir=/var/lib/seaweedfs-volume \
                          -max=100 \
                          -mserver=${lib.concatStringsSep "," masterServersList} \
                          ${lib.optionalString (dataCenter != null) "-dataCenter=${dataCenter}"} \
                          ${lib.optionalString (rack != null) "-rack=${rack}"}
                      '';
                      Restart = "on-failure";
                      RestartSec = "5s";
                    };
                  };
                })

                # Filer server
                (mkIf runFiler {
                  seaweedfs-filer = {
                    description = "SeaweedFS Filer Server";
                    after = [ "network.target" ] ++ lib.optional runMaster "seaweedfs-master.service";
                    wants = lib.optional runMaster "seaweedfs-master.service";
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "simple";
                      DynamicUser = true;
                      StateDirectory = "seaweedfs-filer";
                      RuntimeDirectory = "seaweedfs-filer";
                      ExecStart = ''
                        ${pkgs.seaweedfs}/bin/weed filer \
                          -ip=${if filerDomain != null then "0.0.0.0" else "127.0.0.1"} \
                          -port=8888 \
                          -master=${lib.concatStringsSep "," masterServersList} \
                          ${lib.optionalString s3Enabled "-s3 -s3.port=${toString s3Port}"} \
                          ${lib.optionalString authEnabled "-auth.jwt.signing.key=$(cat ${jwtSigningKeyFile})"} \
                          ${lib.optionalString (dataCenter != null) "-dataCenter=${dataCenter}"} \
                          ${lib.optionalString (rack != null) "-rack=${rack}"}
                      '';
                      Restart = "on-failure";
                      RestartSec = "5s";

                      # Load credentials if auth is enabled
                      LoadCredential = lib.optionals authEnabled [
                        "jwt_signing_key:${jwtSigningKeyFile}"
                      ];
                    };
                  };
                })

                # Authentication configuration service
                (mkIf authEnabled {
                  seaweedfs-auth-config = {
                    description = "Configure SeaweedFS Authentication";
                    after = [ "seaweedfs-master.service" ];
                    requires = [ "seaweedfs-master.service" ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      ExecStart = pkgs.writeScript "seaweedfs-auth-setup" ''
                        #!${pkgs.runtimeShell}
                        set -e

                        # Wait for master to be ready
                        for i in {1..30}; do
                          if ${pkgs.curl}/bin/curl -sf http://localhost:9333/cluster/status >/dev/null; then
                            break
                          fi
                          echo "Waiting for SeaweedFS master to be ready..."
                          sleep 2
                        done

                        # Configure admin user
                        ADMIN_PASSWORD=$(cat ${adminPasswordFile})

                        # Create security.toml configuration
                        cat > /tmp/security.toml <<EOF
                        [jwt.signing]
                        key = "$(cat ${jwtSigningKeyFile})"
                        expires_after_seconds = 3600

                        [[identities]]
                        name = "${adminUsername}"
                        credentials = [
                          { aws_access_key_id = "${adminUsername}", aws_secret_access_key = "$ADMIN_PASSWORD" }
                        ]
                        actions = ["Admin", "Read", "Write"]
                        EOF

                        # Upload security configuration to master
                        ${pkgs.curl}/bin/curl -X POST \
                          -F "file=@/tmp/security.toml" \
                          http://localhost:9333/admin/security/put

                        rm /tmp/security.toml
                        echo "SeaweedFS authentication configured"
                      '';
                    };
                  };
                })
              ];

              # Nginx reverse proxy configuration
              services.nginx = mkIf (masterDomain != null || filerDomain != null || s3Domain != null) {
                enable = true;
                virtualHosts = lib.mkMerge [
                  # Master server proxy
                  (mkIf (masterDomain != null) {
                    ${masterDomain} = {
                      forceSSL = enableSSL;
                      enableACME = enableSSL;
                      locations."/" = {
                        proxyPass = "http://127.0.0.1:9333";
                        proxyWebsockets = true;
                        extraConfig = ''
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Proto $scheme;

                          # Increase timeouts for large file operations
                          proxy_read_timeout 300s;
                          proxy_connect_timeout 75s;
                          client_max_body_size 0;
                        '';
                      };
                    };
                  })

                  # Filer server proxy
                  (mkIf (filerDomain != null) {
                    ${filerDomain} = {
                      forceSSL = enableSSL;
                      enableACME = enableSSL;
                      locations."/" = {
                        proxyPass = "http://127.0.0.1:8888";
                        proxyWebsockets = true;
                        extraConfig = ''
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Proto $scheme;

                          # Increase limits for file uploads
                          proxy_read_timeout 300s;
                          proxy_connect_timeout 75s;
                          client_max_body_size 0;
                          proxy_buffering off;
                          proxy_request_buffering off;
                        '';
                      };
                    };
                  })

                  # S3 API proxy
                  (mkIf (s3Domain != null && s3Enabled) {
                    ${s3Domain} = {
                      forceSSL = enableSSL;
                      enableACME = enableSSL;
                      locations."/" = {
                        proxyPass = "http://127.0.0.1:${toString s3Port}";
                        extraConfig = ''
                          proxy_set_header Host $host;
                          proxy_set_header X-Real-IP $remote_addr;
                          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                          proxy_set_header X-Forwarded-Proto $scheme;

                          # S3 compatibility headers
                          proxy_set_header Authorization $http_authorization;
                          proxy_pass_header Authorization;

                          # Increase limits for S3 operations
                          client_max_body_size 0;
                          proxy_buffering off;
                          proxy_request_buffering off;
                        '';
                      };
                    };
                  })
                ];
              };

              # Open firewall ports
              networking.firewall = {
                allowedTCPPorts = lib.flatten [
                  # Master ports
                  (lib.optional (runMaster && masterDomain == null) 9333)
                  # Volume ports
                  (lib.optional runVolume 8080)
                  # Filer ports
                  (lib.optional (runFiler && filerDomain == null) 8888)
                  # S3 ports
                  (lib.optional (s3Enabled && s3Domain == null) s3Port)
                  # HTTP/HTTPS for nginx
                  (lib.optional (masterDomain != null || filerDomain != null || s3Domain != null) 80)
                  (lib.optional ((masterDomain != null || filerDomain != null || s3Domain != null) && enableSSL) 443)
                ];
              };

              # ACME email configuration
              security.acme =
                mkIf ((masterDomain != null || filerDomain != null || s3Domain != null) && enableSSL)
                  {
                    acceptTerms = true;
                    defaults.email = mkDefault "admin@${
                      if masterDomain != null then
                        masterDomain
                      else if filerDomain != null then
                        filerDomain
                      else
                        s3Domain
                    }";
                  };
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Ensure seaweedfs package is available
        environment.systemPackages = [ pkgs.seaweedfs ];

        # Create vars generators
        clan.core.vars.generators.seaweedfs-auth = {
          files = {
            admin_password = { };
            jwt_signing_key = { };
          };
          runtimeInputs = with pkgs; [
            pwgen
            openssl
          ];
          prompts = { }; # No prompts, auto-generate
          script = ''
            # Generate password
            ${pkgs.pwgen}/bin/pwgen -s 32 1 > "$out"/admin_password

            # Generate JWT signing key
            ${pkgs.openssl}/bin/openssl rand -base64 32 > "$out"/jwt_signing_key
          '';
        };
      };
  };
}
