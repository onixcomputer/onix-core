_: {
  instances = {
    "br-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
          instanceId = "br-tailnet";
        };
      };
    };
  };
}
