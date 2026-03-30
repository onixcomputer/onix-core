# Buildbot CI via buildbot-nix.
#
# Two roles:
#   master — CI coordinator, web UI, GitHub integration, secret management
#   worker — build executor (co-located with master initially)
#
# Co-locate master + worker on the same machine for the common case.
# Harmonia on the same box means builds land in the binary cache with
# zero copy overhead.
{ inputs, schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
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

      interface = mkSettings.mkInterface schema.master;

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
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.master);

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

      interface = mkSettings.mkInterface schema.worker;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, lib, ... }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.worker);
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
