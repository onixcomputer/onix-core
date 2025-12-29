{ pkgs, ... }:
{
  home.packages = [
    pkgs.lazyjj
  ];

  home.shellAliases = {
    ljj = "lazyjj";
  };
}
