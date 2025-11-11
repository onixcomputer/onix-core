{ inputs, pkgs, ... }:
{
  home.packages = [
    (inputs.wrappers.wrapperModules.jjui.apply {
      inherit pkgs;

      settings = {
      };
    }).wrapper
  ];

  home.shellAliases = {
    aa = "jjui";
  };
}
