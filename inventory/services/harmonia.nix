_: {
  instances = {
    "onix-cache" = {
      module.name = "harmonia";
      module.input = "self";
      roles = {
        server = {
          machines.leviathan = { };
          settings = {
            generateSigningKey = true;
            enableNginx = false;
            priority = 25;

            settings = {
              bind = "[::]:5000";
              workers = 2;
              max_connection_rate = 128;
              priority = 25;
            };
          };
        };
        client = {
          machines.sequoia = { };
          settings = {
            serverUrl = "";
            priority = 25;
            extraSubstituters = [ "https://cache.nixos.org/" ];
            extraTrustedPublicKeys = [ ];
          };
        };
      };
    };
  };
}
