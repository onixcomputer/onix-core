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
        freeformType = lib.types.attrsOf lib.types.anything;
        options = { };
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
            runnerName = "${instanceName}-${machineName}";
          in
          {
            services.gitlab-runner = {
              enable = true;
              services."${runnerName}" = settings // {
                authenticationTokenConfigFile =
                  config.clan.core.vars.generators."gitlab-runner-${instanceName}".files."auth-token".path;

                # Add preBuildScript for docker executor with Alpine
                preBuildScript =
                  lib.mkIf ((settings.executor or "shell") == "docker" && (settings.dockerImage or "") == "alpine")
                    (
                      lib.mkDefault (
                        pkgs.writeScript "setup-container" ''
                          mkdir -p -m 0755 /nix/var/log/nix/drvs
                          mkdir -p -m 0755 /nix/var/nix/gcroots
                          mkdir -p -m 0755 /nix/var/nix/profiles
                          mkdir -p -m 0755 /nix/var/nix/temproots
                          mkdir -p -m 0755 /nix/var/nix/userpool
                          mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
                          mkdir -p -m 1777 /nix/var/nix/profiles/per-user
                          mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
                          mkdir -p -m 0700 "$HOME/.nix-defexpr"

                          . ${pkgs.nix}/etc/profile.d/nix-daemon.sh

                          mkdir -p /etc/nix
                          echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

                          ${pkgs.nix}/bin/nix-env -i ${
                            lib.concatStringsSep " " (
                              with pkgs;
                              [
                                nix
                                cacert
                                git
                                openssh
                              ]
                            )
                          }

                          export SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt
                          export NIX_SSL_CERT_FILE=/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt

                          ${pkgs.nix}/bin/nix-channel --add https://nixos.org/channels/nixos-20.09 nixpkgs || true
                          ${pkgs.nix}/bin/nix-channel --update nixpkgs || true
                        ''
                      )
                    );
              };
            };

            systemd.services.gitlab-runner = {
              serviceConfig = {
                ExecStartPre = lib.mkBefore [ "${pkgs.coreutils}/bin/sleep 5" ];
              };
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
            };

            clan.core.vars.generators."gitlab-runner-${instanceName}" = {
              prompts = {
                "auth-token" = {
                  description = ''
                    GitLab Runner authentication token. To create:
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
                  share = true;
                };
              };

              runtimeInputs = [ pkgs.coreutils ];

              script = ''
                cat > "$out/auth-token" <<EOF
                # GitLab Runner authentication configuration
                export CI_SERVER_URL="https://gitlab.com"
                export CI_SERVER_TOKEN="$(tr -d '\n' < "$prompts/auth-token")"
                EOF
                chmod 600 "$out/auth-token"
              '';
            };
          };
      };
  };
}
