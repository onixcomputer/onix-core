{
  inputs,
  self,
  ...
}:
{
  flake =
    let
      inherit (inputs.nixpkgs) lib;

      # Import modules directly
      modules = import "${self}/modules/default.nix" { inherit inputs; };

      # Build clan using new API
      clanModule = inputs.clan-core.lib.clan {
        specialArgs = {
          inherit inputs;
          wrappers = inputs.wrappers.wrapperModules;
        };
        inherit self;
        meta.name = "Onix";
        inherit modules;
        inventory = import "${self}/inventory" { inherit inputs; };

        # Extend the exports schema to support cross-service endpoint discovery.
        # The default only defines `networking` for VPN peers; we add
        # `serviceEndpoints` so the monitoring stack can discover URLs.
        exportsModule = import "${self}/inventory/exports-module.nix" { inherit lib; };
      };
    in
    {
      # Expose clan outputs using new API structure
      inherit (clanModule.config) nixosConfigurations darwinConfigurations clanInternals;
      clan = clanModule.config;
    };
}
