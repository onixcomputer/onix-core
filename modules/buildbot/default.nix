_: {
  _class = "clan.service";
  manifest = {
    name = "buildbot";
    description = "Buildbot CI/CD with GitLab integration and distributed workers";
    categories = [ "Development" ];
  };

  roles.master = {
    interface =
      { lib, ... }:
      {
        # Freeform - pass through any buildbot-nix master options
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          # We only define options we need to handle specially
          enableTailscaleFunnel = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable Tailscale Funnel for webhooks";
          };

          funnelPath = lib.mkOption {
            type = lib.types.str;
            default = "/change_hook/gitlab";
            description = "Path for the Tailscale Funnel webhook endpoint";
          };

          # Provide sensible defaults for required buildbot-nix options
          domain = lib.mkOption {
            type = lib.types.str;
            default = "buildbot.local";
            description = "Domain for buildbot master";
          };
        };
      };

    perInstance =
      {
        roles,
        settings,
        lib,
        ...
      }:
      {
        nixosModule =
          {
            config,
            pkgs,
            inputs,
            ...
          }:
          let
            # Collect all worker machines from the inventory
            workerMachines = roles.worker.machines;

            # Generate list of worker names for the generator script
            workerNames = builtins.attrNames workerMachines;

            # Get cores for each worker from inventory
            workerCores = lib.mapAttrs (_name: machineData: machineData.settings.cores or 4) workerMachines;

            # Remove our special options from settings before passing to buildbot-nix
            buildbotSettings = builtins.removeAttrs settings [
              "enableTailscaleFunnel"
              "funnelPath"
            ];

          in
          {
            imports = [
              inputs.buildbot-nix.nixosModules.buildbot-master
            ];

            services.buildbot-nix.master = buildbotSettings // {
              enable = true;

              # Override workers file
              workersFile = config.clan.core.vars.generators.buildbot-master.files."workers.json".path;

              # GitLab authentication (using gitea backend)
              authBackend = "gitea";
              gitea = (buildbotSettings.gitea or { }) // {
                enable = true;
                tokenFile = config.clan.core.vars.generators.buildbot-master.files."api-token".path;
                webhookSecretFile = config.clan.core.vars.generators.buildbot-master.files."webhook-secret".path;
                # oauthId comes from settings (it's public info)
                # oauthSecret comes from vars
                oauthSecretFile = config.clan.core.vars.generators.buildbot-master.files."oauth-secret".path;
              };
            };

            # TODO: Implement Tailscale Funnel configuration when available
            # services.tailscale.funnel = lib.mkIf settings.enableTailscaleFunnel {
            #   enable = true;
            #   routes = {
            #     "${settings.funnelPath}" = {
            #       backend = "http://localhost:${toString (settings.port or 8010)}";
            #     };
            #   };
            # };

            # Firewall rules if ports are specified
            networking.firewall.allowedTCPPorts =
              lib.optional (settings ? port) settings.port ++ lib.optional (settings ? pbPort) settings.pbPort;

            # Master manages authentication tokens and worker passwords
            clan.core.vars.generators = {
              buildbot-master = {
                prompts = {
                  "api-token" = {
                    description = "GitLab API token (create at GitLab > Settings > Access Tokens with 'api' scope)";
                    type = "hidden";
                  };
                  "oauth-secret" = {
                    description = "GitLab OAuth Application Secret";
                    type = "hidden";
                  };
                };

                files = {
                  "workers.json" = { }; # Always needed for workers
                  "api-token" = { }; # From prompt
                  "webhook-secret" = { }; # From prompt
                  "oauth-secret" = { }; # From prompt
                };

                # Depend on all worker password generators
                dependencies = map (name: "buildbot-worker-${name}") workerNames;

                runtimeInputs = with pkgs; [
                  jq
                  coreutils
                  xkcdpass
                ];

                script = ''
                  # Copy prompted values
                  cp "$prompts/api-token" "$out/api-token"
                  cp "$prompts/oauth-secret" "$out/oauth-secret"

                  # Generate webhook secret automatically
                  xkcdpass -n 6 -d - > "$out/webhook-secret"
                  echo "Generated webhook secret. Use 'clan vars get buildbot-master webhook-secret' to retrieve it for GitLab webhook configuration."

                  # Build the workers.json file with passwords from each worker's generator
                  echo '[' > "$out/workers.json"
                  first=true
                  ${lib.concatMapStringsSep "\n" (workerName: ''
                    if [ "$first" = true ]; then
                      first=false
                    else
                      echo ',' >> "$out/workers.json"
                    fi

                    # Read the password from the worker's generated file
                    PASSWORD=$(cat "$in/buildbot-worker-${workerName}/password")

                    # Append this worker's configuration to the JSON array
                    cat >> "$out/workers.json" << EOF
                    {
                      "name": "${workerName}",
                      "pass": "$PASSWORD",
                      "cores": ${toString workerCores.${workerName}}
                    }
                    EOF
                  '') workerNames}
                  echo ']' >> "$out/workers.json"

                  # Validate the JSON
                  jq . "$out/workers.json" > /dev/null
                '';
              };
            }
            // (lib.mapAttrs' (
              workerName: _workerSettings:
              lib.nameValuePair "buildbot-worker-${workerName}" {
                share = true; # Shared between master and worker machines

                files."password" = { };

                runtimeInputs = with pkgs; [
                  xkcdpass
                ];

                script = ''
                  xkcdpass -n 4 -d - > "$out/password"
                '';
              }
            ) workerMachines);
          };
      };
  };

  roles.worker = {
    interface =
      { lib, ... }:
      {
        # Freeform - pass through any buildbot-nix worker options
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          # Worker-specific options we might need to handle
        };
      };

    perInstance =
      { roles, settings, ... }:
      let
        # Find the master machine (there should be exactly one)
        masterMachines = builtins.attrNames roles.master.machines;
        masterMachine =
          if builtins.length masterMachines != 1 then
            throw "Buildbot instance must have exactly one master, found: ${toString masterMachines}"
          else
            builtins.head masterMachines;

        masterSettings = roles.master.machines.${masterMachine}.settings;

        # Remove any special options before passing to buildbot-nix
        buildbotWorkerSettings = builtins.removeAttrs settings [ "cores" ];
      in
      {
        nixosModule =
          {
            config,
            pkgs,
            inputs,
            ...
          }:
          {
            imports = [
              inputs.buildbot-nix.nixosModules.buildbot-worker
            ];

            services.buildbot-nix.worker = buildbotWorkerSettings // {
              enable = true;

              # Override with our managed settings
              masterUrl = "tcp:host=${masterMachine}:port=${toString (masterSettings.pbPort or 9989)}";
              name = config.networking.hostName;
              workerPasswordFile =
                config.clan.core.vars.generators."buildbot-worker-${config.networking.hostName}".files."password".path;

              # Use cores setting for number of workers (buildbot workers, not machines)
              workers = settings.cores or 0; # 0 means use CPU core count
            };

            # Worker references the same shared generator the master created
            clan.core.vars.generators."buildbot-worker-${config.networking.hostName}" = {
              share = true; # This references the shared secret created by master

              files."password" = { };

              runtimeInputs = with pkgs; [
                xkcdpass
              ];

              script = ''
                xkcdpass -n 4 -d - > "$out/password"
              '';
            };
          };
      };
  };
}
