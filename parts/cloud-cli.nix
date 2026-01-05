# Cloud infrastructure management CLI
# Wraps OpenTofu/Terranix for AWS infrastructure management
_: {
  perSystem =
    { pkgs, ... }:
    {
      packages.cloud-cli = pkgs.writeShellApplication {
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
    };
}
