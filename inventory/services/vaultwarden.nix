_: {
  instances = {
    "vaultwarden" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        tags."vaultwarden-server" = { };
        settings = {
          # All settings can be configured here
          # The module provides sensible defaults
        };
      };
    };
  };
}
