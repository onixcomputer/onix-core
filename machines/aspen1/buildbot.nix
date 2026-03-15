# Buildbot master + worker on aspen1.
#
# Co-located with harmonia: builds that land here are immediately
# available in the binary cache without any copy step.
{
  config,
  inputs,
  pkgs,
  ...
}:
let
  inherit (inputs.buildbot-nix.lib) interpolate;

  # Post-build: notify on failure via ntfy.
  notify-build = pkgs.writeShellScript "notify-build" ''
    set -euo pipefail
    status="$BUILD_STATUS"

    # Only notify on failures
    if [ "$status" = "success" ]; then
      exit 0
    fi

    title="Build $status: $PROJECT"
    body="$ATTR_NAME failed on $PROJECT (branch: $BRANCH)"

    ${pkgs.curl}/bin/curl -sf \
      -H "Title: $title" \
      -H "Priority: high" \
      -H "Tags: warning" \
      -d "$body" \
      "https://ntfy.sh/onix-buildbot" 2>/dev/null || true
  '';
in
{
  imports = [
    inputs.buildbot-nix.nixosModules.buildbot-master
    inputs.buildbot-nix.nixosModules.buildbot-worker
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
          '[{"name": "aspen1", "pass": $pass, "cores": 16}]' \
          > $out/workers
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

  services = {
    buildbot-nix.master = {
      enable = true;
      domain = "buildbot.blr.dev";
      useHTTPS = true;
      workersFile = config.clan.core.vars.generators.buildbot-worker.files.workers.path;
      buildSystems = [
        "x86_64-linux"
      ];

      authBackend = "github";
      github = {
        appId = 3086395;
        appSecretKeyFile = config.clan.core.vars.generators.buildbot-github.files.app-secret-key.path;

        oauthId = "Ov23livGR1RdLhArTbJI";
        oauthSecretFile = config.clan.core.vars.generators.buildbot-github.files.oauth-secret.path;

        webhookSecretFile = config.clan.core.vars.generators.buildbot-github.files.webhook-secret.path;

        topic = "buildbot-nix-brittonr";
      };

      admins = [ "brittonr" ];
      evalWorkerCount = 8;
      evalMaxMemorySize = 4096;

      # Write store paths of successful builds for update-prefetch to curl.
      outputsPath = "/var/www/buildbot/nix-outputs/";

      postBuildSteps = [
        {
          name = "Notify build status";
          environment = {
            BUILD_STATUS = interpolate "%(prop:status_text)s";
            PROJECT = interpolate "%(prop:project)s";
            ATTR_NAME = interpolate "%(prop:attr)s";
            BRANCH = interpolate "%(prop:branch)s";
          };
          command = [ "${notify-build}" ];
          warnOnly = true;
        }
      ];
    };

    buildbot-nix.worker = {
      enable = true;
      workerPasswordFile = config.clan.core.vars.generators.buildbot-worker.files.password.path;
      workers = 16;
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www/buildbot/nix-outputs 0755 buildbot buildbot -"
  ];

  networking.firewall.allowedTCPPorts = [ 80 ];
}
