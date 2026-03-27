# Buildbot CI via buildbot-nix.
#
# Two roles:
#   master — CI coordinator, web UI, GitHub integration, secret management
#   worker — build executor (co-located with master initially)
#
# Co-locate master + worker on the same machine for the common case.
# Harmonia on the same box means builds land in the binary cache with
# zero copy overhead.
{ inputs }:
{ lib, ... }:
let
  inherit (lib) mkOption mkDefault;
  inherit (lib.types)
    attrsOf
    anything
    str
    bool
    int
    listOf
    nullOr
    ;
  inherit (inputs.buildbot-nix.lib) interpolate;
in
{
  _class = "clan.service";

  manifest = {
    name = "buildbot";
    readme = "Buildbot CI via buildbot-nix with clan-managed secrets and inventory-driven configuration";
  };

  roles = {
    master = {
      description = "Buildbot master server (CI coordinator, web UI, GitHub integration)";

      interface = {
        freeformType = attrsOf anything;

        options = {
          domain = mkOption {
            type = str;
            description = "Public domain for the Buildbot web UI";
          };
          useHTTPS = mkOption {
            type = bool;
            default = true;
            description = "Whether to use HTTPS for the web UI";
          };
          buildSystems = mkOption {
            type = listOf str;
            default = [ "x86_64-linux" ];
            description = "Systems to build";
          };
          admins = mkOption {
            type = listOf str;
            default = [ ];
            description = "Users allowed to login and trigger builds";
          };
          evalWorkerCount = mkOption {
            type = int;
            default = 4;
            description = "Number of eval workers";
          };
          evalMaxMemorySize = mkOption {
            type = int;
            default = 2048;
            description = "Max memory per eval worker (MB)";
          };
          outputsPath = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to write store paths of successful builds";
          };
          postBuildSteps = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional post-build steps (appended after ntfy notification if enabled)";
          };
          ntfyUrl = mkOption {
            type = nullOr str;
            default = null;
            description = "ntfy URL for build failure notifications (e.g., https://ntfy.sh/my-topic)";
          };
          github = mkOption {
            type = attrsOf anything;
            default = { };
            description = "GitHub App and OAuth configuration (appId, oauthId, topic)";
          };
          workerName = mkOption {
            type = str;
            description = "Name of the co-located worker (used in workers JSON)";
          };
          workerCores = mkOption {
            type = int;
            default = 16;
            description = "CPU cores for the co-located worker (used in workers JSON)";
          };
          effectsSecrets = mkOption {
            type = attrsOf bool;
            default = { };
            description = ''
              Map of repo identifiers to enable effects secrets for.
              Keys are "github:owner/repo" strings. A clan vars generator
              prompts for a GitHub PAT and produces the hercules-ci JSON format.
            '';
            example = {
              "github:onixcomputer/onix-core" = true;
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
              pkgs,
              lib,
              ...
            }:
            let
              cfg = extendSettings {
                useHTTPS = mkDefault true;
                buildSystems = mkDefault [ "x86_64-linux" ];
                evalWorkerCount = mkDefault 4;
                evalMaxMemorySize = mkDefault 2048;
                admins = mkDefault [ ];
                outputsPath = mkDefault null;
                ntfyUrl = mkDefault null;
                postBuildSteps = mkDefault [ ];
                github = mkDefault { };
                workerCores = mkDefault 16;
                effectsSecrets = mkDefault { };
              };

              # Attrs handled explicitly — don't pass through to services.buildbot-nix.master
              managedAttrs = [
                "domain"
                "useHTTPS"
                "buildSystems"
                "admins"
                "evalWorkerCount"
                "evalMaxMemorySize"
                "outputsPath"
                "postBuildSteps"
                "ntfyUrl"
                "github"
                "workerName"
                "workerCores"
                "effectsSecrets"
              ];
              passthroughSettings = builtins.removeAttrs cfg managedAttrs;

              # ntfy notification script (only evaluated when ntfyUrl is set, via laziness)
              notify-build = pkgs.writeShellApplication {
                name = "notify-build";
                runtimeInputs = [ pkgs.curl ];
                text = ''
                  status="$BUILD_STATUS"

                  # Only notify on failures
                  if [ "$status" = "success" ]; then
                    exit 0
                  fi

                  title="Build $status: $PROJECT"
                  body="$ATTR_NAME failed on $PROJECT (branch: $BRANCH)"

                  curl -sf \
                    -H "Title: $title" \
                    -H "Priority: high" \
                    -H "Tags: warning" \
                    -d "$body" \
                    "${cfg.ntfyUrl}" 2>/dev/null || true
                '';
              };

              ntfySteps = lib.optionals (cfg.ntfyUrl != null) [
                {
                  name = "Notify build status";
                  environment = {
                    BUILD_STATUS = interpolate "%(prop:status_text)s";
                    PROJECT = interpolate "%(prop:project)s";
                    ATTR_NAME = interpolate "%(prop:attr)s";
                    BRANCH = interpolate "%(prop:branch)s";
                  };
                  command = [ (lib.getExe notify-build) ];
                  warnOnly = true;
                }
              ];
            in
            {
              imports = [ inputs.buildbot-nix.nixosModules.buildbot-master ];

              assertions = [
                {
                  assertion = cfg.domain != "";
                  message = "buildbot: 'domain' must be non-empty";
                }
                {
                  assertion = cfg.workerCores >= 1;
                  message = "buildbot: 'workerCores' must be >= 1, got ${toString cfg.workerCores}";
                }
                {
                  assertion = cfg.evalWorkerCount >= 1;
                  message = "buildbot: 'evalWorkerCount' must be >= 1, got ${toString cfg.evalWorkerCount}";
                }
                {
                  assertion = cfg.evalMaxMemorySize >= 256;
                  message = "buildbot: 'evalMaxMemorySize' must be >= 256 MB, got ${toString cfg.evalMaxMemorySize}";
                }
              ];

              clan.core.vars.generators = {
                # Worker password + workers JSON generated together (avoids cross-generator deps)
                buildbot-worker = {
                  files.password = { };
                  files.workers = { };
                  runtimeInputs = [ pkgs.jq ];
                  script = ''
                    head -c 32 /dev/urandom | base64 | tr -d '\n' > $out/password
                    jq -n --arg pass "$(cat $out/password)" \
                      '[{"name": "${cfg.workerName}", "pass": $pass, "cores": ${toString cfg.workerCores}}]' \
                      > $out/workers
                  '';
                };

                # Effects secrets — prompted GitHub PAT in hercules-ci JSON format
                # Format: {"token": {"type": "GitToken", "data": {"token": "ghp_..."}}}
                # The "token" key matches secretsMap.token in hci-effects.flakeUpdate
                onix-effects-secrets = lib.mkIf (cfg.effectsSecrets != { }) {
                  files.secrets-json = { };
                  runtimeInputs = [ pkgs.jq ];
                  prompts.github-pat = {
                    description = "GitHub PAT for effects (fine-grained, contents:write + pull_requests:write)";
                    type = "hidden";
                  };
                  script = ''
                    jq -n --arg token "$(cat $prompts/github-pat)" \
                      '{"token": {"type": "GitToken", "data": {"token": $token}}}' \
                      > $out/secrets-json
                  '';
                };

                # GitHub secrets (prompted — fill in after creating GitHub App + OAuth app)
                buildbot-github = {
                  files = {
                    oauth-secret = { };
                    webhook-secret = { };
                    app-secret-key = { };
                  };
                  prompts = {
                    oauth-secret = {
                      description = "GitHub OAuth client secret (github.com/settings/developers)";
                      type = "hidden";
                    };
                    webhook-secret = {
                      description = "GitHub webhook secret (random string, used when adding repo webhook)";
                      type = "hidden";
                    };
                    app-secret-key = {
                      description = "GitHub App private key PEM (github.com/settings/apps -> Generate a private key)";
                      type = "hidden";
                    };
                  };
                  script = ''
                    cp $prompts/oauth-secret $out/oauth-secret
                    cp $prompts/webhook-secret $out/webhook-secret
                    cp $prompts/app-secret-key $out/app-secret-key
                  '';
                };
              };

              services.buildbot-nix.master = lib.mkMerge [
                {
                  enable = true;
                  inherit (cfg)
                    domain
                    useHTTPS
                    buildSystems
                    admins
                    evalWorkerCount
                    evalMaxMemorySize
                    ;
                  workersFile = config.clan.core.vars.generators.buildbot-worker.files.workers.path;

                  authBackend = "github";
                  github = cfg.github // {
                    appSecretKeyFile = config.clan.core.vars.generators.buildbot-github.files.app-secret-key.path;
                    oauthSecretFile = config.clan.core.vars.generators.buildbot-github.files.oauth-secret.path;
                    webhookSecretFile = config.clan.core.vars.generators.buildbot-github.files.webhook-secret.path;
                  };

                  postBuildSteps = ntfySteps ++ cfg.postBuildSteps;

                  effects.perRepoSecretFiles = lib.mapAttrs (
                    _repoId: _enabled: config.clan.core.vars.generators.onix-effects-secrets.files.secrets-json.path
                  ) (lib.filterAttrs (_: enabled: enabled) cfg.effectsSecrets);
                }
                (lib.mkIf (cfg.outputsPath != null) {
                  inherit (cfg) outputsPath;
                })
                passthroughSettings
              ];

              # Upstream buildbot-nix sets no Restart or TimeoutStopSec.
              # Graceful shutdown cancels all in-flight builds one by one,
              # which can exceed the default 90s. And a CI service should
              # recover from transient failures without manual intervention.
              systemd.services.buildbot-master.serviceConfig = {
                Restart = "on-failure";
                RestartSec = 10;
                TimeoutStopSec = 300;
              };

              systemd.tmpfiles.rules = lib.optionals (cfg.outputsPath != null) [
                "d ${lib.removeSuffix "/" cfg.outputsPath} 0755 buildbot buildbot -"
              ];

              networking.firewall.allowedTCPPorts = [ 80 ];
            };
        };
    };

    worker = {
      description = "Buildbot worker (executes builds on this machine)";

      interface = {
        freeformType = attrsOf anything;

        options = {
          workers = mkOption {
            type = int;
            default = 0;
            description = "Number of worker processes (0 = number of CPU cores)";
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              cfg = extendSettings {
                workers = mkDefault 0;
              };
              managedAttrs = [ "workers" ];
              passthroughSettings = builtins.removeAttrs cfg managedAttrs;
            in
            {
              imports = [ inputs.buildbot-nix.nixosModules.buildbot-worker ];

              services.buildbot-nix.worker = lib.mkMerge [
                {
                  enable = true;
                  workerPasswordFile = config.clan.core.vars.generators.buildbot-worker.files.password.path;
                  inherit (cfg) workers;
                }
                passthroughSettings
              ];
            };
        };
    };
  };
}
