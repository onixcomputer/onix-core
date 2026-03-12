_: {
  instances = {
    sshd = {
      module.name = "sshd";
      roles.server.tags.nixos = { };
    };
  };
}
