{ inputs, ... }:
{
  imports = [
    inputs.pinenote-nixos.nixosModules.default
  ];

  # Enable PineNote hardware support
  pinenote.config.enable = true;

  # ARM64 platform
  nixpkgs.hostPlatform = "aarch64-linux";
}
