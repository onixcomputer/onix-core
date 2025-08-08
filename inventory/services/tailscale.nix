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

    # Personal Gmail tailnet
    "gmail-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-brittonrobitzsch@gmail.com" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
          instanceId = "gmail-tailnet";
        };
      };
    };
  };
}
