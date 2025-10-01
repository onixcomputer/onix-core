{ ... }:
{
  instances = {
    demo = {
      module.name = "clan-var-echo";
      module.input = "self";

      roles.server = {
        tags."echo" = { };
        settings = {
          message = "Hello from microvm tag-based service deployment!";
          interval = "2m"; # Echo every 2 minutes for quicker testing
        };
      };
    };
  };
}
