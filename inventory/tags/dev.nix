{ pkgs, ... }:
{
  programs.direnv.enable = true;
  environment.systemPackages = with pkgs; [
    claude-code
    comma
    gh
    nixpkgs-review
    goose-cli
    net-tools
    nix-output-monitor
    nmap
    pamtester
    usbmuxd
    usbutils
    radicle-node
    socat
    lsof
    jujutsu
    socat
    lsof
  ];
}
