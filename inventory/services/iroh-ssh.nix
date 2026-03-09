_: {
  instances = {

    "iroh-ssh" = {
      module.name = "iroh-ssh";
      module.input = "self";
      roles.peer = {
        tags."tailnet-brittonr" = { };
        settings = {
          persist = true;
        };
      };
    };

  };
}
