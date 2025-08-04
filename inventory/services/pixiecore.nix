_: {
  instances = {
    "pixiecore" = {
      module.name = "pixiecore";
      module.input = "self";
      roles.server = {
        tags."pixiecore-server" = { };
        settings = {
          # Enable pixiecore by default for tagged machines
          enable = true;

          # Back to API mode
          mode = "api";
          apiServer = "http://localhost:8080";

          # Let pixiecore handle DHCP fully
          dhcpNoBind = false;

          # Enable debug logging
          extraOptions = [ "--debug" ];

          # SSH keys to serve to netboot clients
          sshAuthorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
          ];

        };
      };
    };
  };
}
