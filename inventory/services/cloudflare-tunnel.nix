_: {
  instances = {

    "cloudflare-adeci" = {
      module.name = "cloudflare-tunnel";
      module.input = "self";
      roles.default = {
        machines.sequoia = {
          settings = {
            tunnelName = "sequoia-services";
            ingress = {
              "vault.decio.us" = "http://localhost:8222";
              "auth.decio.us" = "http://localhost:9080";
            };
          };
        };
        # machines.marine = {
        #   settings = {
        #     tunnelName = "marine-services";
        #     ingress = {
        #       "buildbot.decio.us" = "http://localhost:8010";
        #     };
        #   };
        # };
      };
    };

    "cloudflare-brittonr" = {
      module.name = "cloudflare-tunnel";
      module.input = "self";
      roles.default = {
        machines.aspen1 = {
          settings = {
            tunnelName = "aspen1-services";
            ingress = {
              "vault.robitzs.ch" = "http://localhost:8222";
            };
          };
        };
      };
    };

  };
}
