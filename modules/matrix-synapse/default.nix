{
  _class = "clan.service";
  manifest.name = "matrix-synapse";

  roles = {
    server = {
      interface =
        { lib, ... }:
        {
          freeformType = with lib; attrsOf anything;

          options = {
            # Clan-specific options only
            server_name = lib.mkOption {
              type = lib.types.str;
              description = "The server name for the Matrix homeserver (e.g., example.com)";
              example = "example.com";
            };

            domain = lib.mkOption {
              type = lib.types.str;
              description = "The domain where the Matrix server will be accessible";
              example = "matrix.example.com";
            };

            enable_element = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether to serve Element web client alongside Matrix Synapse";
            };

            database = {
              type = lib.mkOption {
                type = lib.types.enum [
                  "sqlite3"
                  "postgresql"
                ];
                default = "postgresql";
                description = "Database backend to use";
              };
            };

            federation = {
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
                description = "Enable federation with other Matrix servers";
              };
            };

            registration = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable open registration";
              };
            };

            users = lib.mkOption {
              default = { };
              type = lib.types.attrsOf (
                lib.types.submodule (
                  { name, ... }:
                  {
                    options = {
                      name = lib.mkOption {
                        type = lib.types.str;
                        default = name;
                        description = "The name of the user";
                      };
                      admin = lib.mkOption {
                        type = lib.types.bool;
                        default = false;
                        description = "Whether the user should be an admin";
                      };
                    };
                  }
                )
              );
              description = "Users to create on the Matrix server";
              example.alice = {
                admin = true;
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
              # Get all settings
              settings = extendSettings { };

              # Extract clan-specific options
              inherit (settings)
                server_name
                domain
                enable_element
                database
                registration
                users
                ;

              # Remove clan-specific options before passing to services.matrix-synapse
              synapseConfig = builtins.removeAttrs settings [
                "server_name"
                "domain"
                "enable_element"
                "database"
                "federation"
                "registration"
                "users"
              ];

              element-web =
                pkgs.runCommand "element-web-with-config"
                  {
                    nativeBuildInputs = [ pkgs.buildPackages.jq ];
                  }
                  ''
                    cp -r ${pkgs.element-web} $out
                    chmod -R u+w $out
                    jq '."default_server_config"."m.homeserver" = { "base_url": "https://${domain}:443", "server_name": "${server_name}" }' \
                      > $out/config.json < ${pkgs.element-web}/config.json
                    ln -s $out/config.json $out/config.${domain}.json
                  '';
            in
            {
              services = {
                matrix-synapse = lib.mkMerge [
                  {
                    enable = true;
                    settings = {
                      inherit server_name;
                      public_baseurl = "https://${domain}";

                      database = lib.mkIf (database.type == "postgresql") {
                        name = "psycopg2";
                        args = {
                          user = "matrix-synapse";
                          database = "matrix-synapse";
                        };
                      };

                      listeners = [
                        {
                          port = 8008;
                          bind_addresses = [
                            "::1"
                            "127.0.0.1"
                          ];
                          type = "http";
                          tls = false;
                          x_forwarded = true;
                          resources = [
                            {
                              names = [
                                "client"
                                "federation"
                              ];
                              compress = true;
                            }
                          ];
                        }
                      ];

                      enable_registration = registration.enable;
                      registration_shared_secret_path = "/run/synapse-registration-shared-secret";
                      signing_key_path = "/var/lib/matrix-synapse/signing.key";
                    };
                  }
                  # Pass through any additional matrix-synapse configuration
                  (if synapseConfig ? settings then { inherit (synapseConfig) settings; } else { })
                  (builtins.removeAttrs synapseConfig [ "settings" ])
                ];

                postgresql = lib.mkIf (database.type == "postgresql") {
                  enable = true;
                  ensureDatabases = [ "matrix-synapse" ];
                  ensureUsers = [
                    {
                      name = "matrix-synapse";
                      ensureDBOwnership = true;
                    }
                  ];
                };

                nginx = {
                  enable = true;

                  virtualHosts = {
                    "${server_name}" = {
                      enableACME = true;
                      forceSSL = true;

                      locations = {
                        "= /.well-known/matrix/server".extraConfig = ''
                          add_header Content-Type application/json;
                          return 200 '${builtins.toJSON { "m.server" = "${domain}:443"; }}';
                        '';

                        "= /.well-known/matrix/client".extraConfig = ''
                          add_header Content-Type application/json;
                          add_header Access-Control-Allow-Origin *;
                          return 200 '${
                            builtins.toJSON {
                              "m.homeserver" = {
                                "base_url" = "https://${domain}";
                              };
                              "m.identity_server" = {
                                "base_url" = "https://vector.im";
                              };
                            }
                          }';
                        '';
                      };
                    };

                    "${domain}" = {
                      enableACME = true;
                      forceSSL = true;

                      locations = lib.mkMerge [
                        (lib.mkIf enable_element {
                          "/" = {
                            root = element-web;
                          };
                        })
                        {
                          "/_matrix" = {
                            proxyPass = "http://localhost:8008";
                            proxyWebsockets = true;
                          };

                          "/_synapse/client" = {
                            proxyPass = "http://localhost:8008";
                          };
                        }
                      ];
                    };
                  };
                };
              };

              networking.firewall.allowedTCPPorts = [
                80
                443
              ];

              clan.core.vars.generators = {
                "matrix-synapse-signing-key" = {
                  prompts = { };
                  migrateFact = "matrix-synapse-signing-key";
                  script =
                    { pkgs, ... }:
                    ''
                      ${pkgs.matrix-synapse}/bin/generate_signing_key > "$out"/signing.key
                    '';
                  files."signing.key" = { };
                };

                "matrix-synapse-registration-secret" = {
                  prompts = { };
                  migrateFact = "matrix-synapse-registration-secret";
                  script =
                    { pkgs, ... }:
                    ''
                      ${pkgs.pwgen}/bin/pwgen -s 32 1 > "$out"/registration-secret
                    '';
                  files."registration-secret" = { };
                };
              }
              // lib.mapAttrs' (
                name: user:
                lib.nameValuePair "matrix-password-${user.name}" {
                  prompts = { };
                  migrateFact = "matrix-password-${user.name}";
                  script =
                    { pkgs, ... }:
                    ''
                      ${pkgs.xkcdpass}/bin/xkcdpass -n 4 -d - > "$out"/matrix-password-${user.name}
                    '';
                  files."matrix-password-${user.name}" = { };
                }
              ) users;

              systemd.services.matrix-synapse = {
                preStart = lib.mkAfter ''
                  # Copy signing key
                  install -m 0600 -o matrix-synapse -g matrix-synapse \
                    ${config.clan.core.vars.generators.matrix-synapse-signing-key.files."signing.key".path} \
                    /var/lib/matrix-synapse/signing.key

                  # Copy registration secret  
                  install -m 0600 -o matrix-synapse -g matrix-synapse \
                    ${
                      config.clan.core.vars.generators.matrix-synapse-registration-secret.files."registration-secret".path
                    } \
                    /run/synapse-registration-shared-secret
                '';

                postStart =
                  let
                    usersScript = ''
                      # Wait for service to be ready
                      while ! ${pkgs.netcat}/bin/nc -z -v ::1 8008; do
                        if ! kill -0 "$MAINPID"; then exit 1; fi
                        sleep 1;
                      done
                    ''
                    + lib.concatMapStringsSep "\n" (user: ''
                      # Create user if it doesn't exist
                      /run/current-system/sw/bin/matrix-synapse-register_new_matrix_user \
                        --exists-ok \
                        --password-file ${
                          config.clan.core.vars.generators."matrix-password-${user.name}".files."matrix-password-${user.name}".path
                        } \
                        --user "${user.name}" \
                        ${if user.admin then "--admin" else "--no-admin"} \
                        http://localhost:8008
                    '') (lib.attrValues users);
                  in
                  lib.mkIf (users != { }) ''
                    ${pkgs.writeShellScript "matrix-synapse-create-users" usersScript}
                  '';
              };
            };
        };
    };
  };
}
