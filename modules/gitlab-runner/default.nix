_: {
  _class = "clan.service";

  manifest = {
    name = "gitlab-runner";
    description = "GitLab CI/CD Runner - Execute GitLab pipelines on your infrastructure";
    categories = [
      "Development"
      "CI/CD"
    ];
  };

  roles.default = {
    interface =
      { lib, ... }:
      {
        options.runners = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule {
              freeformType = lib.types.attrsOf lib.types.anything;
              options = { };
            }
          );
          default = { };
          description = "GitLab runner configurations";
        };
      };

    perInstance =
      {
        instanceName,
        settings,
        ...
      }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            machineName = config.networking.hostName;

            # Process each runner in the instance
            runnerConfigs = lib.mapAttrs' (
              runnerKey: runnerSettings:
              let
                runnerName = "${instanceName}-${runnerKey}-${machineName}";
              in
              lib.nameValuePair runnerName (
                runnerSettings
                // {
                  authenticationTokenConfigFile =
                    config.clan.core.vars.generators."gitlab-runner-${instanceName}-${runnerKey}".files."auth-token".path;

                  preBuildScript = lib.mkIf (runnerSettings ? preBuildScript) (
                    pkgs.writeScript "pre-build-script" runnerSettings.preBuildScript
                  );
                }
              )
            ) settings.runners;
          in
          {
            # Add all runners from this instance to the daemon
            services.gitlab-runner.services = runnerConfigs;

            # Generate auth token for each runner
            clan.core.vars.generators = lib.mkMerge (
              [
                # Shared SSH key generator for the instance
                {
                  "gitlab-runner-ssh-${instanceName}" = {
                    share = true; # Share SSH keys across all machines in the instance

                    prompts = { }; # No prompts needed - auto-generates

                    files = {
                      "ssh-key" = {
                        mode = "0640"; # Allow group read for gitlab-runner
                        group = "keys";
                        deploy = true;
                      };
                      "ssh-key.pub" = {
                        secret = false; # Public key is not secret
                        deploy = true;
                      };
                    };

                    runtimeInputs = with pkgs; [
                      coreutils
                      openssh
                    ];

                    script = ''
                      # Generate SSH keypair
                      echo "Generating SSH keypair for GitLab Runner instance ${instanceName}..."
                      ssh-keygen -t ed25519 -f "$out/ssh-key" -N "" -C "gitlab-runner-${instanceName}"

                      chmod 600 "$out/ssh-key"
                      chmod 644 "$out/ssh-key.pub"

                      echo ""
                      echo "SSH public key for GitLab Runner instance ${instanceName}:"
                      echo "================================================"
                      cat "$out/ssh-key.pub"
                      echo "================================================"
                      echo "Add this key as a deploy key to your GitLab projects:"
                      echo "1. Go to Project → Settings → Repository → Deploy Keys"
                      echo "2. Add the above public key with read access"
                    '';
                  };
                }
              ]
              # Generate a separate auth token for each runner
              ++ (lib.mapAttrsToList (runnerKey: _runnerSettings: {
                "gitlab-runner-${instanceName}-${runnerKey}" = {
                  # NOT shared - each runner needs its own auth token

                  prompts = {
                    "auth-token" = {
                      description = ''
                        GitLab Runner authentication token for ${instanceName}/${runnerKey}. To create:
                        1. Go to GitLab → Settings → CI/CD → Runners
                        2. Click "New project/group/instance runner"
                        3. Configure runner settings and click "Create runner"
                        4. Copy the authentication token (starts with 'glrt-')
                      '';
                      type = "hidden";
                    };
                  };

                  files = {
                    "auth-token" = {
                      group = "keys";
                      mode = "0440"; # Allow group read
                    };
                  };

                  runtimeInputs = [ pkgs.coreutils ];

                  script = ''
                    # Generate auth token file
                    cat > "$out/auth-token" <<EOF
                    # GitLab Runner authentication configuration
                    export CI_SERVER_URL="https://gitlab.com"
                    export CI_SERVER_TOKEN="$(tr -d '\n' < "$prompts/auth-token")"
                    EOF
                    chmod 600 "$out/auth-token"
                  '';
                };
              }) settings.runners)
            );
          };
      };
  };

  perMachine = {
    nixosModule =
      {
        pkgs,
        lib,
        ...
      }:
      {
        services.gitlab-runner = {
          enable = true;
          settings = {
            concurrent = 100; # High enough to not be a bottleneck, actual limits controlled by individual runners
          };
        };

        systemd.services.gitlab-runner = {
          serviceConfig = {
            ExecStartPre = lib.mkBefore [ "${pkgs.coreutils}/bin/sleep 5" ];
            # Add gitlab-runner to keys group to read secrets
            SupplementaryGroups = [ "keys" ];
          };
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
        };
      };
  };
}
