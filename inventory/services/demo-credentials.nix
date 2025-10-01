{ ... }:
{
  instances = {
    demo = {
      module.name = "demo-credentials";
      module.input = "self";

      roles.server = {
        tags."demo" = { };
        settings = {
          environment = "microvm-test";
          cluster = "onix-core";
          serviceName = "demo-oem-credentials";
        };
      };
    };
  };
}
