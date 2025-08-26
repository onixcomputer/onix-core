_: {
  instances = {
    "adeci-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        tags."vaultwarden-adeci" = { };
        settings = {
          enableCloudflare = true;
          cloudflareHostname = "vault.decio.us";
        };
      };
    };
  };
}
