# Every NixOS machine installs the shared font (inventory/tags/nixos.nix).
{
  berkeley-mono-font = {
    service = "berkeley-mono-font",
    roles.default.tags = ["nixos"],
  },
}
