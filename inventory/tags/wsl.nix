{ inputs, ... }:
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  wsl.enable = true;

  # WSL has its own DNS resolution
  services.resolved.enable = false;
}
