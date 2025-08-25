{ pkgs, ... }:
{
  programs.direnv.enable = true;
  environment.systemPackages = with pkgs; [
    claude-code
    comma
    gh
    nix-output-monitor
    pamtester
  ];
}
