{ pkgs, ... }:
{
  programs.direnv.enable = true;
  environment.systemPackages = with pkgs; [
    btop
    claude-code
    comma
    gh
    goose-cli
    nix-output-monitor
    pamtester
  ];
}
