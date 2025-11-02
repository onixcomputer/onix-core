{ pkgs, ... }:
{
  home.packages = with pkgs; [
    prusa-slicer
    gimp
    #davinci-resolve
  ];
}
