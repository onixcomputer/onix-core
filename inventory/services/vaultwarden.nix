_: {
  instances = {

    "adeci-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        machines.sequoia = { };
        settings = {
          enableCloudflare = true;
          cloudflareHostname = "vault.decio.us";
        };
      };
    };

    "brittonr-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        machines.aspen1 = { };
        settings = {
          enableCloudflare = true;
          cloudflareHostname = "vault.robitzs.ch";
        };
      };
    };

  };
}
