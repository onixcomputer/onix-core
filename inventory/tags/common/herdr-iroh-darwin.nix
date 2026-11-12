{
  inputs,
  pkgs,
  ...
}:
let
  herdrIrohPackage = inputs.herdr-iroh.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  # The relay itself is a per-user LaunchAgent in the `herdr` Home Manager
  # profile (darwin-relay.nix); the system only provides the CLI.
  environment.systemPackages = [ herdrIrohPackage ];
}
