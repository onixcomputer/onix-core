# Cloud infrastructure management CLI
# Wraps OpenTofu/Terranix for AWS infrastructure management
# Access via: .#packages.<system>.cloud-cli
{ pkgs, ... }:
let
  cloudCli = pkgs.writeShellApplication {
    name = "cloud";
    runtimeInputs = with pkgs; [
      terranix
      opentofu
      awscli2
      jq
      coreutils
      gnugrep
      gnused
    ];
    text = builtins.readFile ../scripts/cloud.sh;
  };
in
{
  packages.cloud-cli = cloudCli;
}
