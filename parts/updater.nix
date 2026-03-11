_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.updater = pkgs.callPackage ../pkgs/updater { };
    };
}
