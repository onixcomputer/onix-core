_: {
  instances = {
    "vars-decryption-test" = {
      module.name = "clan-devshell";
      module.input = "self";
      roles.developer = {
        # Only target britton-fw for testing
        machines."britton-fw" = { };

        settings = {
          enable = true;
          enableSystemdService = true;
          testInterval = "daily"; # Run test once per day
        };
      };
    };
  };
}
