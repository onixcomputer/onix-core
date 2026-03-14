# Buildbot master + worker on aspen2.
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

  # Post-build: push outputs from remote workers into the local store.
  # Builds that ran on aspen2 are already local — this is a no-op for those.
  # Builds from remote workers (aspen1) need to be copied here so harmonia
  # can serve them.
  push-to-cache = pkgs.writeShellScript "push-to-cache" ''
    set -euo pipefail
    if [ -z "$OUT_PATH" ] || [ "$OUT_PATH" = "None" ]; then
      echo "No output path — skipping cache push"
      exit 0
    fi

    # Check if the path is already in our store (built locally)
    if ${config.nix.package}/bin/nix-store --check-validity "$OUT_PATH" 2>/dev/null; then
      echo "Already in local store: $OUT_PATH"
      exit 0
    fi

    # Path was built on a remote worker — pull it
    echo "Fetching $OUT_PATH from builder..."
    ${config.nix.package}/bin/nix-store --add-root /run/buildbot-cache -r "$OUT_PATH" 2>&1 || \
      echo "Cache fetch failed (non-fatal)"
  '';

  # Post-build: send notification on failure via ntfy.
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

  # --- Vars generators ---
  # Workers JSON lists all workers that connect to this master.
  # Each worker has its own password generator; the master assembles them.
  clan.core.vars.generators = {
    buildbot-worker-aspen2 = {
      files.password = { };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        head -c 32 /dev/urandom | base64 | tr -d '\n' > $out/password
      '';
    };

    # aspen1's worker password is shared so aspen1 can read it too
    buildbot-worker-aspen1 = {
      share = true;
      files.password = { };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        head -c 32 /dev/urandom | base64 | tr -d '\n' > $out/password
      '';
    };

    buildbot-workers = {
      dependencies = [
        "buildbot-worker-aspen1"
        "buildbot-worker-aspen2"
      ];
      files."workers.json" = { };
      runtimeInputs = [ pkgs.jq ];
      script = ''
        pass1=$(cat "$in/buildbot-worker-aspen1/password")
        pass2=$(cat "$in/buildbot-worker-aspen2/password")
        jq -n \
          --arg p1 "$pass1" \
          --arg p2 "$pass2" \
          '[
            {"name": "aspen1", "pass": $p1, "cores": 16},
            {"name": "aspen2", "pass": $p2, "cores": 16}
          ]' > "$out/workers.json"
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
    # --- Master ---
    buildbot-nix.master = {
      enable = true;
      domain = "buildbot.blr.dev";
      useHTTPS = true;
      workersFile = config.clan.core.vars.generators.buildbot-workers.files."workers.json".path;
      buildSystems = [
        "x86_64-linux"
        "aarch64-linux"
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
          name = "Push to harmonia cache";
          environment = {
            OUT_PATH = interpolate "%(prop:out_path)s";
          };
          command = [ "${push-to-cache}" ];
          warnOnly = true;
        }
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

    # --- Local worker ---
    buildbot-nix.worker = {
      enable = true;
      workerPasswordFile = config.clan.core.vars.generators.buildbot-worker-aspen2.files.password.path;
      workers = 16;
    };

    # --- Nginx: serve buildbot UI + outputs index ---
    nginx.virtualHosts."buildbot.blr.dev" = {
      locations."/nix-outputs/" = {
        alias = "/var/www/buildbot/nix-outputs/";
        extraConfig = ''
          autoindex on;
        '';
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/www/buildbot/nix-outputs 0755 buildbot buildbot -"
  ];

  networking.firewall.allowedTCPPorts = [
    80 # nginx (buildbot UI + outputs)
    9989 # buildbot master pb port (remote workers)
  ];
}
