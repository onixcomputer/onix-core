{ pkgs, ... }:
{
  programs.direnv.enable = true;
  environment.systemPackages = with pkgs; [
    claude-code
    comma
    gh
    nixpkgs-review
    goose-cli
    nix-output-monitor
    pamtester
    usbmuxd
  ];
}
