{
  _class,
  ...
}:
{
  # The two classes have disjoint options (`services.herdr-iroh` exists only
  # on NixOS), so import only the matching implementation. A `mkIf` cannot
  # hide an option that the current class does not declare.
  imports = [
    (if _class == "nixos" then ./herdr-iroh-nixos.nix else ./herdr-iroh-darwin.nix)
  ];
}
