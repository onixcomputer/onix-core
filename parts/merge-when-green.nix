_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.merge-when-green = pkgs.callPackage ../pkgs/merge-when-green { };
    };
}
