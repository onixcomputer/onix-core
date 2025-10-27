{ pkgs, ... }:
{
  # Enable cross-compilation support
  nixpkgs.config.allowUnsupportedSystem = true;

  # Add cross-compilation toolchains
  environment.systemPackages = with pkgs; [
    # Cross-compilation tools
    qemu

    # Build essentials for cross-compilation
    binutils-unwrapped
    gcc-unwrapped

    # Useful for debugging cross-compiled binaries
    file
    binutils # provides readelf
  ];

  # Enable binfmt for running cross-compiled binaries via QEMU
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "armv7l-linux"
    "riscv64-linux"
  ];
}
