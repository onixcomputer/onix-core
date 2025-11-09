{
  nix-cache = {
    module = {
      name = "trusted-nix-caches";
      input = "clan-core";
    };
    roles.default.machines = [ "all" ];
  };
}
