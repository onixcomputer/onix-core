{
  inputs,
  self,
  ...
}:
{
  flake =
    let
      # Import modules directly
      modules = import "${self}/modules/default.nix" { inherit inputs; };

      # Build clan using new API
      clanModule = inputs.clan-core.lib.clan {
        specialArgs = { inherit inputs; };
        inherit self;
        meta.name = "Onix";
        inherit modules;
        inventory = import "${self}/inventory" { inherit inputs; };
      };
    in
    {
      # Expose clan outputs using new API structure
      inherit (clanModule.config) nixosConfigurations clanInternals;
      clan = clanModule.config;
    };
}
