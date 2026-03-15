_: {
  instances = {
    buildbot = {
      module.name = "buildbot";
      module.input = "self";

      roles.master = {
        machines."aspen1" = { };
        settings = {
          domain = "buildbot.blr.dev";
          useHTTPS = true;
          buildSystems = [ "x86_64-linux" ];
          admins = [ "brittonr" ];
          evalWorkerCount = 8;
          evalMaxMemorySize = 4096;
          outputsPath = "/var/www/buildbot/nix-outputs/";
          ntfyUrl = "https://ntfy.sh/onix-buildbot";
          workerName = "aspen1";
          workerCores = 16;
          github = {
            appId = 3086395;
            oauthId = "Ov23livGR1RdLhArTbJI";
            topic = "buildbot-nix-brittonr";
          };
          effectsSecrets = {
            "github:onixcomputer/onix-core" = true;
          };
        };
      };

      roles.worker = {
        machines."aspen1" = { };
        settings = {
          workers = 16;
        };
      };
    };
  };
}
