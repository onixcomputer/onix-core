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

              # SQL initialization script for stub database
              initDbScript = pkgs.writeText "wiki-js-init.sql" ''
                -- Create migrations table
                CREATE TABLE IF NOT EXISTS migrations (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255),
                    batch INTEGER,
                    migration_time TIMESTAMPTZ
                );

                -- Create settings table
                CREATE TABLE IF NOT EXISTS settings (
                    key VARCHAR(255) PRIMARY KEY,
                    value TEXT
                );

                -- Create users table
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    email VARCHAR(255) UNIQUE,
                    name VARCHAR(255),
                    "providerId" VARCHAR(255),
                    password VARCHAR(255),
                    "tfaIsActive" BOOLEAN DEFAULT false,
                    "tfaSecret" VARCHAR(255),
                    "jobTitle" VARCHAR(255),
                    location VARCHAR(255),
                    "pictureUrl" TEXT,
                    timezone VARCHAR(255) DEFAULT 'America/New_York',
                    "isSystem" BOOLEAN DEFAULT false,
                    "isActive" BOOLEAN DEFAULT false,
                    "isVerified" BOOLEAN DEFAULT false,
                    "mustChangePwd" BOOLEAN DEFAULT false,
                    "createdAt" TIMESTAMP DEFAULT NOW(),
                    "updatedAt" TIMESTAMP DEFAULT NOW()
                );

                -- Create groups table
                CREATE TABLE IF NOT EXISTS groups (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR(255) UNIQUE,
                    "isSystem" BOOLEAN DEFAULT false,
                    permissions TEXT,
                    "pageRules" TEXT,
                    "createdAt" TIMESTAMP DEFAULT NOW(),
                    "updatedAt" TIMESTAMP DEFAULT NOW()
                );

                -- Create userGroups table
                CREATE TABLE IF NOT EXISTS "userGroups" (
                    "userId" INTEGER NOT NULL,
                    "groupId" INTEGER NOT NULL,
                    PRIMARY KEY ("userId", "groupId")
                );

                -- Create other required tables (can be empty initially)
                CREATE TABLE IF NOT EXISTS authentication (
                    key VARCHAR(255) PRIMARY KEY,
                    "isEnabled" BOOLEAN DEFAULT false,
                    config TEXT,
                    "selfRegistration" BOOLEAN DEFAULT false,
                    "domainWhitelist" TEXT,
                    "autoEnrollGroups" TEXT
                );

                CREATE TABLE IF NOT EXISTS editors (
                    key VARCHAR(255) PRIMARY KEY,
                    "isEnabled" BOOLEAN DEFAULT false,
                    config TEXT
                );

                CREATE TABLE IF NOT EXISTS locales (
                    code VARCHAR(5) PRIMARY KEY,
                    strings TEXT,
                    "isRTL" BOOLEAN DEFAULT false,
                    name VARCHAR(255),
                    "nativeName" VARCHAR(255),
                    availability INTEGER DEFAULT 0,
                    "createdAt" TIMESTAMP DEFAULT NOW(),
                    "updatedAt" TIMESTAMP DEFAULT NOW()
                );

                CREATE TABLE IF NOT EXISTS navigation (
                    key VARCHAR(255) PRIMARY KEY,
                    config TEXT
                );

                CREATE TABLE IF NOT EXISTS pages (
                    id SERIAL PRIMARY KEY,
                    path VARCHAR(255),
                    hash VARCHAR(255),
                    title VARCHAR(255),
                    description TEXT,
                    "isPrivate" BOOLEAN DEFAULT false,
                    "isPublished" BOOLEAN DEFAULT false,
                    "publishStartDate" TIMESTAMP,
                    "publishEndDate" TIMESTAMP,
                    tags TEXT,
                    content TEXT,
                    render TEXT,
                    "contentType" VARCHAR(255),
                    "createdAt" TIMESTAMP DEFAULT NOW(),
                    "updatedAt" TIMESTAMP DEFAULT NOW(),
                    "editorKey" VARCHAR(255),
                    "localeCode" VARCHAR(5),
                    "authorId" INTEGER,
                    "creatorId" INTEGER,
                    extra TEXT
                );

                CREATE TABLE IF NOT EXISTS "pageTree" (
                    id INTEGER PRIMARY KEY,
                    path VARCHAR(255),
                    depth INTEGER,
                    title VARCHAR(255),
                    "isPrivate" BOOLEAN DEFAULT false,
                    "isFolder" BOOLEAN DEFAULT false,
                    "privateNS" VARCHAR(255),
                    parent INTEGER,
                    "pageId" INTEGER,
                    "localeCode" VARCHAR(5),
                    ancestors INTEGER[]
                );

                CREATE TABLE IF NOT EXISTS renderers (
                    key VARCHAR(255) PRIMARY KEY,
                    "isEnabled" BOOLEAN DEFAULT false,
                    config TEXT
                );

                CREATE TABLE IF NOT EXISTS storage (
                    key VARCHAR(255) PRIMARY KEY,
                    "isEnabled" BOOLEAN DEFAULT false,
                    mode VARCHAR(255) DEFAULT 'push',
                    config TEXT,
                    "syncInterval" VARCHAR(255),
                    state TEXT
                );

                CREATE TABLE IF NOT EXISTS "searchEngines" (
                    key VARCHAR(255) PRIMARY KEY,
                    "isEnabled" BOOLEAN DEFAULT false,
                    config TEXT
                );

                -- Insert migration record
                INSERT INTO migrations (name, batch, migration_time) 
                VALUES ('2.0.0.js', 1, NOW())
                ON CONFLICT DO NOTHING;

                -- Insert essential settings to bypass setup
                INSERT INTO settings (key, value) VALUES 
                ('setup', '"completed"'),
                ('siteTitle', '"Wiki.js"'),
                ('company', '""'),
                ('contentLicense', '""'),
                ('logoUrl', '""'),
                ('telemetry', '"false"'),
                ('upgrade', '"stable"')
                ON CONFLICT (key) DO NOTHING;

                -- Insert default groups
                INSERT INTO groups (id, name, "isSystem", permissions, "pageRules") VALUES 
                (1, 'Administrators', true, '["manage:system","write:pages","manage:pages","delete:pages","manage:groups","manage:users","manage:navigation","manage:theme","manage:api"]', '[]'),
                (2, 'Guests', true, '["read:pages"]', '[{"id":"guest","path":"","roles":["read:pages"],"match":"START","deny":false,"locales":[]}]')
                ON CONFLICT DO NOTHING;

                -- Admin user will be inserted by the initialization service with proper password
              '';

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
                (mkIf (dbAutoSetup && dbType == "postgres") (
                  let
                    # Admin credentials files from clan vars
                    adminEmailFile = config.clan.core.vars.generators.wiki-js-admin.files.email.path;
                    adminPasswordHashFile = config.clan.core.vars.generators.wiki-js-admin.files.password_hash.path;
                  in
                  {
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

                    "wiki-js-init-db" = {
                      description = "Initialize Wiki.js database";
                      after = [
                        "postgresql.service"
                        "postgresql-set-wiki-js-password.service"
                      ];
                      requires = [
                        "postgresql.service"
                        "postgresql-set-wiki-js-password.service"
                      ];
                      before = [ "wiki-js.service" ];
                      wantedBy = [ "multi-user.target" ];
                      serviceConfig = {
                        Type = "oneshot";
                        RemainAfterExit = true;
                        User = "root";
                        ExecStart = pkgs.writeScript "wiki-js-init-db" ''
                          #!${pkgs.runtimeShell}
                          set -e

                          # Check if database is already initialized
                          if ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql -d ${dbName} -c "SELECT 1 FROM migrations LIMIT 1;" &>/dev/null; then
                            echo "Wiki.js database already initialized, skipping..."
                            exit 0
                          fi

                          echo "Initializing Wiki.js database..."

                          # Run the initialization SQL
                          ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql -d ${dbName} < ${initDbScript}

                          # Insert admin user with generated credentials
                          ADMIN_EMAIL=$(cat ${adminEmailFile})
                          ADMIN_HASH=$(cat ${adminPasswordHashFile})

                          ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql -d ${dbName} <<EOF
                          INSERT INTO users (id, email, name, "providerId", password, "isSystem", "isActive", "isVerified", "createdAt", "updatedAt") 
                          VALUES (1, '\$ADMIN_EMAIL', 'Administrator', 'local', '\$ADMIN_HASH', false, true, true, NOW(), NOW())
                          ON CONFLICT (id) DO UPDATE SET 
                            email = EXCLUDED.email,
                            password = EXCLUDED.password;
                            
                          -- Add admin to administrators group
                          INSERT INTO "userGroups" ("userId", "groupId") 
                          VALUES (1, 1)
                          ON CONFLICT DO NOTHING;
                          EOF

                          # Configure git storage if enabled
                          ${lib.optionalString gitSyncEnabled ''
                            echo "Configuring git storage..."
                            SSH_KEY_PATH="${
                              if gitSshKeyFile != null then
                                gitSshKeyFile
                              else
                                config.clan.core.vars.generators.wiki-js-git.files.ssh_key.path
                            }"

                            ${pkgs.sudo}/bin/sudo -u postgres ${config.services.postgresql.package}/bin/psql -d ${dbName} <<EOF
                            -- Enable git storage
                            INSERT INTO storage (key, "isEnabled", mode, config) VALUES (
                              'git',
                              true,
                              'sync',
                              '{
                                "type": "git",
                                "repoUrl": "${gitRepository}",
                                "branch": "${gitBranch}",
                                "sshPrivateKeyPath": "'$SSH_KEY_PATH'",
                                "sshPrivateKeyMode": "path",
                                "authType": "ssh",
                                "gitBinaryPath": "${pkgs.git}/bin/git",
                                "defaultEmail": "${gitAuthorEmail}",
                                "defaultName": "${gitAuthorName}",
                                "localRepoPath": "./data/repo"
                              }'
                            ) ON CONFLICT (key) DO UPDATE SET
                              "isEnabled" = EXCLUDED."isEnabled",
                              mode = EXCLUDED.mode,
                              config = EXCLUDED.config;
                            EOF
                          ''}

                          echo "Wiki.js database initialization complete"
                        '';
                      };
                    };
                  }
                ))
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

                    # Ensure password and database are initialized before starting
                    after = lib.optionals (dbAutoSetup && dbType == "postgres") [
                      "postgresql-set-wiki-js-password.service"
                      "wiki-js-init-db.service"
                    ];
                    wants = lib.optionals (dbAutoSetup && dbType == "postgres") [
                      "postgresql-set-wiki-js-password.service"
                      "wiki-js-init-db.service"
                    ];

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
        # Create vars generators
        clan.core.vars.generators = {
          wiki-js-db = {
            files.password = { };
            runtimeInputs = [ pkgs.pwgen ];
            prompts = { };
            script = ''
              ${pkgs.pwgen}/bin/pwgen -s 32 1 > "$out"/password
            '';
          };

          wiki-js-admin = {
            files = {
              email = { };
              password = { };
              password_hash = { };
            };
            runtimeInputs = with pkgs; [
              pwgen
            ];
            prompts = { };
            script = ''
                            # Use proper admin email
                            echo "admin@blr.dev" > "$out"/email
                            
                            # Generate secure password
                            ${pkgs.pwgen}/bin/pwgen -s 20 1 > "$out"/password
                            
                            # Generate bcrypt hash for the password using python with bcrypt package
                            ${pkgs.python3.withPackages (ps: with ps; [ bcrypt ])}/bin/python3 <<'EOF'
              import bcrypt
              import os
              password = open(os.environ['out'] + '/password', 'r').read().strip()
              salt = bcrypt.gensalt(12)
              hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
              open(os.environ['out'] + '/password_hash', 'w').write(hashed.decode('utf-8'))
              EOF
            '';
          };

          wiki-js-git = {
            files = {
              ssh_key = {
                owner = "wiki-js";
                mode = "0600";
              };
              "ssh_key.pub" = {
                owner = "wiki-js";
                mode = "0644";
              };
            };
            runtimeInputs = [ pkgs.openssh ];
            prompts = { };
            script = ''
              ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -f "$out"/ssh_key -N "" -C "wiki-js@localhost"
            '';
          };
        };
      };
  };
}
