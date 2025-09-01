_: {
  instances = {
    "adeci" = {
      module.name = "keycloak";
      module.input = "self";
      roles.server = {
        machines.sequoia = { };
        settings = {
          domain = "auth.decio.us";

          settings = {
            http-port = 8080;
          };
        };
      };
    };
  };
}
