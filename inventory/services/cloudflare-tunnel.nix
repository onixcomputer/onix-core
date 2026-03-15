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
              "buildbot.blr.dev" = "http://localhost:80";
              "matrix.onix.computer" = "http://localhost:80";
              # Matrix well-known delegation (federation discovery on server_tld)
              "onix.computer" = "http://localhost:80";
            };
          };
        };
      };
    };

  };
}
