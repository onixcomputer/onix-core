{ pkgs, ... }:
{
  home.packages = [
    pkgs.jjui
  ];

  home.shellAliases = {
    aa = "jjui";
  };
}
