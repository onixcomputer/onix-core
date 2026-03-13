_: {
  instances = {
    sshd = {
      module.name = "sshd";
      roles = {
        server.tags.nixos = { };
        client = {
          tags.nixos = { };
          settings.certificate.searchDomains = [ "local" ];
        };
      };
    };
  };
}
