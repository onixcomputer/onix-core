_: {
  instances = {
    upmpdcli = {
      module.name = "upmpdcli";
      module.input = "self";
      roles.server = {
        tags = [ "media" ]; # Deploy to machines with media tag
      };
    };
  };
}
