{
  config,
  inputs,
  pkgs,
  ...
}:
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
      runtimeInputs = with pkgs; [ jq ];
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

  services.buildbot-nix.master = {
    enable = true;
    domain = "buildbot.aspen1.local";
    workersFile = config.clan.core.vars.generators.buildbot-worker.files.workers.path;
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

      # Repos with this topic are auto-discovered
      topic = "buildbot-onix";
    };

    admins = [ "brittonr" ];
    evalWorkerCount = 8;
    evalMaxMemorySize = 4096;
  };

  services.buildbot-nix.worker = {
    enable = true;
    workerPasswordFile = config.clan.core.vars.generators.buildbot-worker.files.password.path;
    workers = 16;
  };

  networking.firewall.allowedTCPPorts = [ 80 ];
}
