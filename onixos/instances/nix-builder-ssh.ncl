# Machines tagged remote-builders reach their builders with this key.
{
  nix-builder-ssh = {
    service = "nix-builder-ssh",
    roles.default.tags = ["remote-builders"],
  },
}
