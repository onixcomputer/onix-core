{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    taskwarrior3
    taskwarrior-tui
    tasksh
  ];
}
