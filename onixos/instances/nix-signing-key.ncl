# Every NixOS machine has a Nix store signing key (inventory/tags/nixos.nix).
{
  nix-signing-key = {
    service = "nix-signing-key",
    roles.default.tags = ["nixos"],
  },
}
