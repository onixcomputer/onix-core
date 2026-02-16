_: {
  instances = {

    "iroh-ssh" = {
      module.name = "iroh-ssh";
      module.input = "self";
      roles.peer = {
        tags."tailnet-adeci" = { };
        settings = {
          persist = true;
        };
      };
    };

  };
}
