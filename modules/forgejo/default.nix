{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    bool
    str
    nullOr
    attrsOf
    anything
    enum
    port
    ;
in
{
  _class = "clan.service";
  manifest.name = "forgejo";

  roles = {
    server = {
      interface = {
        # Allow freeform configuration that maps directly to services.forgejo
        freeformType = attrsOf anything;

        options = {
          # Clan-specific convenience options
          domain = mkOption {
            type = str;
            default = "forgejo.localhost";
            description = "Domain name for Forgejo";
          };

          enableNginx = mkOption {
            type = bool;
            default = true;
            description = "Whether to enable Nginx reverse proxy with ACME";
          };

          enableDatabase = mkOption {
            type = bool;
            default = true;
            description = "Whether to automatically configure PostgreSQL database";
          };

          databaseType = mkOption {
            type = enum [
              "postgres"
              "mysql"
              "sqlite3"
            ];
            default = "postgres";
            description = "Database type to use";
          };

          enableMailer = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable email functionality";
          };

          smtpHost = mkOption {
            type = nullOr str;
            default = null;
            description = "SMTP server hostname";
          };

          smtpPort = mkOption {
            type = nullOr port;
            default = null;
            description = "SMTP server port";
          };

          smtpFrom = mkOption {
            type = nullOr str;
            default = null;
            description = "Email address to send from";
          };

          enableLFS = mkOption {
            type = bool;
            default = true;
            description = "Whether to enable Git Large File Storage";
          };

          sshPort = mkOption {
            type = port;
            default = 22;
            description = "SSH port for git operations";
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
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                domain
                enableNginx
                enableDatabase
                databaseType
                enableMailer
                smtpHost
                smtpPort
                smtpFrom
                enableLFS
                sshPort
                ;

              # Remove clan-specific options before passing to services.forgejo
              forgejoConfig = builtins.removeAttrs settings [
                "domain"
                "enableNginx"
                "enableDatabase"
                "databaseType"
                "enableMailer"
                "smtpHost"
                "smtpPort"
                "smtpFrom"
                "enableLFS"
                "sshPort"
              ];

              # Use clan vars for secrets
              secretKeyFile = config.clan.core.vars.generators.forgejo-secrets.files."secret-key".path;
              internalTokenFile = config.clan.core.vars.generators.forgejo-secrets.files."internal-token".path;
              lfsJwtSecretFile = config.clan.core.vars.generators.forgejo-secrets.files."lfs-jwt-secret".path;
              # oauth2JwtSecretFile = config.clan.core.vars.generators.forgejo-secrets.files."oauth2-jwt-secret".path;

              # Database configuration based on type
              databaseConfig =
                if enableDatabase then
                  {
                    database = {
                      type = databaseType;
                    }
                    // (
                      if databaseType == "postgres" then
                        {
                          host = "/run/postgresql";
                          name = "forgejo";
                          user = "forgejo";
                        }
                      else if databaseType == "mysql" then
                        {
                          host = "localhost";
                          name = "forgejo";
                          user = "forgejo";
                          passwordFile = config.clan.core.vars.generators.forgejo-db-password.files."password".path;
                        }
                      else
                        {
                          # sqlite3
                          path = "/var/lib/forgejo/data/forgejo.db";
                        }
                    );
                  }
                else
                  { };

              # Mailer configuration
              mailerConfig =
                if enableMailer && smtpHost != null then
                  {
                    mailer = {
                      enabled = true;
                      from = smtpFrom;
                      mailerType = "smtp";
                      host = smtpHost;
                      port = smtpPort;
                      user = mkDefault "";
                    };
                  }
                else
                  { };

            in
            {
              # Database password for MySQL
              clan.core.vars.generators = mkMerge [
                {
                  forgejo-secrets = {
                    prompts = { };
                    migrateFact = "forgejo-secrets";
                    runtimeInputs = [ pkgs.pwgen ];
                    script = ''
                      # Generate secret key
                      pwgen -s 64 1 > "$out"/secret-key

                      # Generate internal token
                      pwgen -s 64 1 > "$out"/internal-token

                      # Generate LFS JWT secret
                      pwgen -s 64 1 > "$out"/lfs-jwt-secret
                    '';
                    files = {
                      "secret-key" = {
                        owner = "forgejo";
                        group = "forgejo";
                        mode = "0400";
                      };
                      "internal-token" = {
                        owner = "forgejo";
                        group = "forgejo";
                        mode = "0400";
                      };
                      "lfs-jwt-secret" = {
                        owner = "forgejo";
                        group = "forgejo";
                        mode = "0400";
                      };
                    };
                  };
                }
                (mkIf (enableDatabase && databaseType == "mysql") {
                  forgejo-db-password = {
                    prompts = { };
                    migrateFact = "forgejo-db-password";
                    runtimeInputs = [ pkgs.pwgen ];
                    script = ''
                      pwgen -s 32 1 > "$out"/password
                    '';
                    files."password" = {
                      owner = "forgejo";
                      group = "forgejo";
                      mode = "0400";
                    };
                  };
                })
              ];

              services = {
                forgejo = mkMerge [
                  {
                    enable = true;
                    lfs.enable = enableLFS;

                    settings = mkMerge [
                      {
                        server = {
                          DOMAIN = domain;
                          ROOT_URL = "https://${domain}/";
                          HTTP_PORT = mkDefault 3001;
                          SSH_PORT = sshPort;
                        }
                        // lib.optionalAttrs enableLFS {
                          LFS_JWT_SECRET = "_file:${lfsJwtSecretFile}";
                        };

                        security = {
                          SECRET_KEY = "_file:${secretKeyFile}";
                          INTERNAL_TOKEN = "_file:${internalTokenFile}";
                        };

                        session = {
                          COOKIE_SECURE = mkDefault true;
                        };

                        service = {
                          DISABLE_REGISTRATION = mkDefault true;
                          ENABLE_NOTIFY_MAIL = enableMailer;
                        };

                        log = {
                          LEVEL = mkDefault "Info";
                        };
                      }
                      databaseConfig
                      mailerConfig
                    ];
                  }
                  forgejoConfig
                ];

                # PostgreSQL setup
                postgresql = mkIf (enableDatabase && databaseType == "postgres") {
                  enable = true;
                  ensureDatabases = [ "forgejo" ];
                  ensureUsers = [
                    {
                      name = "forgejo";
                      ensureDBOwnership = true;
                    }
                  ];
                };

                # MySQL setup
                mysql = mkIf (enableDatabase && databaseType == "mysql") {
                  enable = true;
                  ensureDatabases = [ "forgejo" ];
                  ensureUsers = [
                    {
                      name = "forgejo";
                      ensurePermissions = {
                        "forgejo.*" = "ALL PRIVILEGES";
                      };
                    }
                  ];
                };

                # Nginx reverse proxy with ACME
                nginx = mkIf enableNginx {
                  enable = true;
                  recommendedProxySettings = true;
                  recommendedTlsSettings = true;
                  recommendedOptimisation = true;
                  recommendedGzipSettings = true;

                  virtualHosts.${domain} = {
                    # Only enable ACME if the user has configured it
                    enableACME = mkDefault (config.security.acme.acceptTerms or false);
                    # Use HTTPS if ACME is enabled, otherwise just HTTP
                    forceSSL = mkDefault (config.security.acme.acceptTerms or false);
                    locations."/" = {
                      proxyPass = "http://localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}";
                      extraConfig = ''
                        client_max_body_size 512M;
                      '';
                    };
                  };
                };
              };

              # Firewall rules
              networking.firewall = {
                allowedTCPPorts =
                  lib.optional enableNginx 80 ++ lib.optional enableNginx 443 ++ lib.optional (sshPort != 22) sshPort;
              };

              # Set MySQL password if using MySQL
              systemd.services.forgejo = mkIf (enableDatabase && databaseType == "mysql") {
                preStart = mkMerge [
                  (mkIf (databaseType == "mysql") ''
                    # Wait for MySQL to be ready
                    while ! ${pkgs.mariadb}/bin/mysqladmin ping -h localhost --silent; do
                      sleep 1
                    done

                    # Set the password for forgejo user
                    ${pkgs.mariadb}/bin/mysql -e "ALTER USER 'forgejo'@'localhost' IDENTIFIED BY '$(cat ${
                      config.clan.core.vars.generators.forgejo-db-password.files."password".path
                    })';"
                  '')
                ];
              };

              # Ensure forgejo user exists with correct permissions
              users.users.forgejo = {
                isSystemUser = true;
                group = "forgejo";
                home = "/var/lib/forgejo";
                useDefaultShell = true;
              };

              users.groups.forgejo = { };
            };
        };
    };
  };

  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Ensure forgejo package is available
        environment.systemPackages = [ pkgs.forgejo ];
      };
  };
}
