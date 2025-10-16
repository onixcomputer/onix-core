_: {
  instances = {
    "adeci" = {
      module.name = "keycloak";
      module.input = "self";
      roles.server = {
        machines.aspen1 = { };
        settings = {
          domain = "auth.robitzs.ch";
          nginxPort = 9081;

          settings = {
            http-port = 8080;
          };
        };
      };
    };
  };
}
