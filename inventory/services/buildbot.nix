_: {
  instances = {
    "buildbot-adeci" = {
      module.name = "buildbot";
      module.input = "self";

      roles.master = {
        machines.marine = { };
        settings = {
          domain = "buildbot.decio.us";
          useHTTPS = true;
          gitea = {
            instanceUrl = "https://gitlab.com";
            oauthId = "3d231f22dce4cc2285a88b76c4deda80dbeec4c371e2b10ccc938f4527e74e6c";
            repoAllowlist = [
              "BrittonR/dpe_demo"
            ];
          };

          evalWorkerCount = 8;
          evalMaxMemorySize = 4096;

          admins = [ "adeci" ];
          buildSystems = [ "x86_64-linux" ];
        };
      };

      roles.worker = {
        machines = {
          marine.settings = {
            cores = 8;
          };
          sequoia.settings = {
            cores = 8;
          };
        };
      };
    };

  };
}
