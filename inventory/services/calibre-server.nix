_: {
  instances = {
    "calibre" = {
      module.name = "calibre-server";
      module.input = "self";
      roles.server = {
        machines."britton-desktop" = { };
        settings = {
          libraries = [ "/home/brittonr/Calibre-Library" ];
          host = "0.0.0.0";
          port = 6767;
          user = "brittonr";
          group = "brittonr";
        };
      };
    };
  };
}
