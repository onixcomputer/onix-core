# Clan instance user-brittonr (inventory/core/users.ncl:22-41). UID, shell
# and SSH keys come from inventory/tags/common/shared-users.nix.
{
  user-brittonr = {
    service = "users",
    roles.default = {
      tags = ["nixos"],
      settings = {
        user = "brittonr",
        prompt = true,
        groups = ["wheel", "networkmanager", "video", "audio", "input", "kvm", "docker", "dialout", "disk"],
      },
    },
  },
}
