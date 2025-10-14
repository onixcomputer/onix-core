_: {
  instances = {

    "adeci-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-adeci" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
          enableHostAliases = true;
          extraUpFlags = [ "--accept-dns=false" ];
        };
      };
    };

    "br-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-brittonr" = { };
        settings = {
          enableSSH = true;
          exitNode = false;
          enableHostAliases = true;
        };
      };
    };

    "dima-tailnet" = {
      module.name = "tailscale";
      module.input = "self";
      roles.peer = {
        tags."tailnet-dima" = { };
        settings = {
          enableSSH = false;
          exitNode = false;
          enableHostAliases = true;
        };
      };
    };
  };
}
