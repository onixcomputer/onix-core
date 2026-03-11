_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.ccusage = pkgs.callPackage ../pkgs/ccusage { };
    };
}
