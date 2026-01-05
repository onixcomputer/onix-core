# Cloud infrastructure management CLI
# Wraps OpenTofu/Terranix for AWS infrastructure management
# Access via: .#clanTools.<system>.cloud or .#packages.<system>.cloud-cli
_: {
  perSystem =
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
      # Expose via custom transposed output
      clanTools.cloud = cloudCli;

      # Also expose via standard packages for backward compatibility
      packages.cloud-cli = cloudCli;
    };
}
