_: {
  instances = {
    "br-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-brittonr" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
        };
      };
    };

    # Alex's tailnet for adeci machines
    "adeci-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-adeci" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
        };
      };
    };
  };
}
