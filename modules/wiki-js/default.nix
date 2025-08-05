{ lib, ... }:
let
  inherit (lib) mkOption mkDefault mkIf;
  inherit (lib.types)
    bool
    str
    nullOr
    attrsOf
    anything
    enum
    ;
in
{
  _class = "clan.service";
  manifest.name = "wiki-js";

  roles = {
    server = {
      interface = {
        # Allow freeform configuration that maps directly to services.wiki-js.settings
        freeformType = attrsOf anything;

        options = {
          # Clan-specific options
          domain = mkOption {
            type = nullOr str;
            default = null;
            description = "Domain name for the Wiki.js instance (enables nginx reverse proxy)";
            example = "wiki.example.com";
          };

          enableSSL = mkOption {
            type = bool;
            default = true;
            description = "Enable SSL/TLS with ACME certificates when domain is set";
          };

          database = {
            type = mkOption {
              type = enum [
                "postgres"
                "mysql"
                "mariadb"
                "mssql"
              ];
              default = "postgres";
              description = "Database type to use";
            };

            autoSetup = mkOption {
              type = bool;
              default = true;
              description = "Automatically setup local database instance";
            };

            host = mkOption {
              type = nullOr str;
              default = null;
              description = "Database host (defaults to local socket)";
            };

            name = mkOption {
              type = str;
              default = "wiki";
              description = "Database name";
            };

            user = mkOption {
              type = str;
              default = "wiki-js";
              description = "Database user";
            };
          };

          gitSync = {
            enable = mkOption {
              type = bool;
              default = false;
              description = "Enable git synchronization for wiki content";
            };

            repository = mkOption {
              type = nullOr str;
              default = null;
              description = "Git repository URL (SSH or HTTPS)";
              example = "git@github.com:myorg/wiki-content.git";
            };

            branch = mkOption {
              type = str;
              default = "main";
              description = "Git branch to use for synchronization";
            };

            sshKeyFile = mkOption {
              type = nullOr str;
              default = null;
              description = "Path to SSH private key for git authentication (will be auto-generated if null)";
            };

            authorName = mkOption {
              type = str;
              default = "Wiki.js";
              description = "Git commit author name";
            };

            authorEmail = mkOption {
              type = str;
              default = "wiki-js@localhost";
              description = "Git commit author email";
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
              inherit (settings) domain enableSSL;
              database = if settings ? database && settings.database != null then settings.database else { };
              dbType = database.type or "postgres";
              dbAutoSetup = database.autoSetup or true;
              dbHost =
                if database ? host && database.host != null then
                  database.host
                else if dbType == "postgres" then
                  "localhost" # Use localhost for postgres
                else if dbType == "mysql" || dbType == "mariadb" then
                  "localhost"
                else
                  "localhost";
              dbName = database.name or "wiki";
              dbUser = database.user or "wiki-js";

              # Git sync options
              gitSync = settings.gitSync or { };
              gitSyncEnabled = gitSync.enable or false;
              gitRepository = gitSync.repository or null;
              gitBranch = gitSync.branch or "main";
              gitAuthorName = gitSync.authorName or "Wiki.js";
              gitAuthorEmail = gitSync.authorEmail or "wiki-js@localhost";
              gitSshKeyFile =
                gitSync.sshKeyFile or (
                  if gitSyncEnabled && gitRepository != null then
                    config.clan.core.vars.generators.wiki-js-git.files.ssh_key.path
                  else
                    null
                );

              # Remove clan-specific options before passing to services.wiki-js
              wikiJsSettings = builtins.removeAttrs settings [
                "domain"
                "enableSSL"
                "database"
                "gitSync"
              ];

              # Database password file from clan vars
              dbPasswordFile = config.clan.core.vars.generators.wiki-js-db.files.password.path;

            in
            {
              # Services configuration
              services = {
                # Wiki.js service
                wiki-js = lib.mkMerge [
                  {
                    enable = true;
                    settings = {
                      # Database configuration
                      db = {
                        type = dbType;
                        host = dbHost;
                        db = dbName;
                        user = dbUser;
                        pass = "_CLAN_DB_PASSWORD_"; # Placeholder to be replaced at runtime
                      };
                      # Default to listening on localhost when using nginx
                      bindIP = mkDefault (if domain != null then "127.0.0.1" else "0.0.0.0");
                    };
                  }
                  { settings = wikiJsSettings; }
                ];

                # Database setup
                postgresql = mkIf (dbAutoSetup && dbType == "postgres") {
                  enable = true;
                  ensureDatabases = [ dbName ];
                  ensureUsers = [
                    {
                      name = dbUser;
                      ensureDBOwnership = true;
                    }
                  ];
                };

                mysql = mkIf (dbAutoSetup && (dbType == "mysql" || dbType == "mariadb")) {
                  enable = true;
                  package = if dbType == "mariadb" then pkgs.mariadb else pkgs.mysql;
                  ensureDatabases = [ dbName ];
                  ensureUsers = [
                    {
                      name = dbUser;
                      ensurePermissions = {
                        "${dbName}.*" = "ALL PRIVILEGES";
                      };
                    }
                  ];
                };

                # Nginx reverse proxy
                nginx = mkIf (domain != null) {
                  enable = true;
                  virtualHosts.${domain} = {
                    forceSSL = enableSSL;
                    enableACME = enableSSL;
                    locations."/" = {
                      proxyPass = "http://127.0.0.1:${toString config.services.wiki-js.settings.port}";
                      proxyWebsockets = true;
                      extraConfig = ''
                        proxy_set_header Host $host;
                        proxy_set_header X-Real-IP $remote_addr;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Forwarded-Proto $scheme;

                        # Increase buffer sizes for large wiki pages
                        proxy_buffer_size 128k;
                        proxy_buffers 4 256k;
                        proxy_busy_buffers_size 256k;

                        # Longer timeouts for wiki operations
                        proxy_read_timeout 300s;
                        proxy_connect_timeout 75s;
                      '';
                    };
                  };
                };
              };

              # Set database password for local databases
              systemd.services = lib.mkMerge [
                (mkIf (dbAutoSetup && dbType == "postgres") {
                  "postgresql-set-wiki-js-password" = {
                    description = "Set Wiki.js PostgreSQL user password";
                    after = [ "postgresql.service" ];
                    requires = [ "postgresql.service" ];
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      User = "root";
                      ExecStart = pkgs.writeScript "set-wiki-js-db-password" ''
                        #!${pkgs.runtimeShell}
                        set -e
                        # Wait for PostgreSQL to be ready
                        while ! ${config.services.postgresql.package}/bin/pg_isready -U postgres; do
                          sleep 1
                        done
                        # Set the password
                        PASSWORD=$(cat ${dbPasswordFile})
                        ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql -c "ALTER USER \"${dbUser}\" WITH PASSWORD '$PASSWORD';"
                      '';
                    };
                  };
                })
                (mkIf (dbAutoSetup && (dbType == "mysql" || dbType == "mariadb")) {
                  mysql.postStart = lib.mkAfter ''
                    ${config.services.mysql.package}/bin/mysql -e "ALTER USER '${dbUser}'@'localhost' IDENTIFIED BY '$(cat ${dbPasswordFile})';"
                  '';
                })
                # Wiki.js service configuration for git support
                {
                  wiki-js = {
                    # Add git and openssh to PATH for git sync functionality
                    path = with pkgs; [
                      git
                      openssh
                    ];

                    # Ensure password is set before starting
                    after = lib.optional (
                      dbAutoSetup && dbType == "postgres"
                    ) "postgresql-set-wiki-js-password.service";
                    wants = lib.optional (
                      dbAutoSetup && dbType == "postgres"
                    ) "postgresql-set-wiki-js-password.service";

                    # Load database password as a credential
                    serviceConfig = {
                      LoadCredential = [ "dbpass:${dbPasswordFile}" ];
                      # Run password replacement as root before dropping privileges
                      ExecStartPre = [
                        "+${pkgs.writeScript "wiki-js-setup-password" ''
                          #!${pkgs.runtimeShell}
                          set -e

                          # Generate Wiki.js config with actual password at runtime
                          if [ -f "${dbPasswordFile}" ]; then
                            echo "Setting up Wiki.js configuration with database password..."
                            DB_PASSWORD=$(cat ${dbPasswordFile})
                            
                            # Wiki.js expects its config in the state directory
                            CONFIG_PATH="/var/lib/${config.services.wiki-js.stateDirectoryName}/config.yml"
                            
                            # Wait for config file to exist (created by NixOS module)
                            for i in {1..10}; do
                              if [ -f "$CONFIG_PATH" ]; then
                                break
                              fi
                              echo "Waiting for config file to be created..."
                              sleep 1
                            done
                            
                            # Replace the password placeholder
                            if [ -f "$CONFIG_PATH" ]; then
                              ${pkgs.gnused}/bin/sed -i "s/_CLAN_DB_PASSWORD_/$DB_PASSWORD/g" "$CONFIG_PATH"
                              echo "Updated Wiki.js configuration with database password"
                              # Fix ownership after modification
                              chown wiki-js:wiki-js "$CONFIG_PATH"
                            else
                              echo "Error: Wiki.js config file not found at $CONFIG_PATH"
                              exit 1
                            fi
                          else
                            echo "Error: Database password file not found at ${dbPasswordFile}"
                            exit 1
                          fi
                        ''}"
                      ];
                    };

                    preStart = lib.mkAfter ''
                      ${lib.optionalString gitSyncEnabled ''
                        # Ensure git is configured for the wiki-js user
                        export HOME=/var/lib/${config.services.wiki-js.stateDirectoryName}
                        ${pkgs.git}/bin/git config --global user.name "${gitAuthorName}"
                        ${pkgs.git}/bin/git config --global user.email "${gitAuthorEmail}"
                        ${pkgs.git}/bin/git config --global init.defaultBranch "${gitBranch}"

                        ${lib.optionalString (gitSshKeyFile != null) ''
                          # Set up SSH key permissions
                          mkdir -p $HOME/.ssh
                          cp ${gitSshKeyFile} $HOME/.ssh/wiki_deploy_key
                          chmod 600 $HOME/.ssh/wiki_deploy_key

                          # Configure SSH to use the deploy key
                          cat > $HOME/.ssh/config <<EOF
                          Host *
                            IdentityFile $HOME/.ssh/wiki_deploy_key
                            StrictHostKeyChecking no
                            UserKnownHostsFile /dev/null
                          EOF
                          chmod 600 $HOME/.ssh/config
                        ''}
                      ''}
                    '';
                  };
                }
              ];

              # Open firewall ports
              networking.firewall = {
                allowedTCPPorts =
                  lib.optional (domain == null) config.services.wiki-js.settings.port
                  ++ lib.optional (domain != null && enableSSL) 443
                  ++ lib.optional (domain != null) 80;
              };

              # ACME email configuration
              security.acme = mkIf (domain != null && enableSSL) {
                acceptTerms = true;
                defaults.email = mkDefault "admin@${domain}";
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
        # Create vars generator for database password
        clan.core.vars.generators.wiki-js-db = {
          files.password = { };
          runtimeInputs = [ pkgs.pwgen ];
          prompts = { };
          script = ''
            ${pkgs.pwgen}/bin/pwgen -s 32 1 > "$out"/password
          '';
        };

        # Create vars generator for git SSH key
        clan.core.vars.generators.wiki-js-git = {
          files.ssh_key = {
            owner = "wiki-js";
            mode = "0600";
          };
          files."ssh_key.pub" = {
            owner = "wiki-js";
            mode = "0644";
          };
          runtimeInputs = [ pkgs.openssh ];
          prompts = { };
          script = ''
            ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$out"/ssh_key -N "" -C "wiki-js@localhost"
          '';
        };
      };
  };
}
