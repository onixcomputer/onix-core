_: {
  instances = {

    "iroh-ssh" = {
      module.name = "iroh-ssh";
      module.input = "self";
      roles.peer = {
        tags."tailnet-brittonr" = { };
        machines."utm-vm" = { };
        settings = {
          sshPort = 22;
        };
      };
    };

  };
}
