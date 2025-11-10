{ inputs, pkgs, ... }:
{
  home.packages = [
    (inputs.wrappers.wrapperModules.lazyjj.apply {
      inherit pkgs;

      settings = {
        # LazyJJ settings can be added here
        # See https://github.com/Cretezy/lazyjj for configuration options
      };
    }).wrapper
  ];

  home.shellAliases = {
    ljj = "lazyjj";
  };
}
