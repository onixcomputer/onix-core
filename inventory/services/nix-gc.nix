_: {
  instances = {
    "store-maintenance" = {
      module.name = "nix-gc";
      module.input = "self";
      roles.default.tags.all = { };
      roles.default.settings = {
        retentionDays = 30;
        schedule = "weekly";
        optimizeStore = true;
        autoOptimise = true;
      };
    };
  };
}
