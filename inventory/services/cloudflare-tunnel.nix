_: {
  instances = {

    "cloudflare-brittonr" = {
      module.name = "cloudflare-tunnel";
      module.input = "self";
      roles.default = {
        machines.aspen1 = {
          settings = {
            tunnelName = "aspen1-services";
            ingress = {
              "vault.robitzs.ch" = "http://localhost:8222";
              "auth.robitzs.ch" = "http://localhost:9081";
              "clonadic.blr.dev" = "http://localhost:8080";
            };
          };
        };
        machines.aspen2 = {
          settings = {
            tunnelName = "aspen2-services";
            ingress = {
              "buildbot.blr.dev" = "http://localhost:80";
            };
          };
        };
      };
    };

  };
}
