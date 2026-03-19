# User inventory — source of truth.
#
# Defines user instances (password/groups) and home-manager profile
# assignments. Validated by Nickel contracts at export time.
#
# `profilesBasePath` is intentionally omitted — it's a Nix path that
# gets injected by inventory/core/default.nix after evaluation.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/core/users.ncl
#   3. Contracts check profile names, tags, machine refs — typos fail immediately
#   4. Commit .ncl
#
let { ValidateUserRefs, .. } = import "user-contracts.ncl" in

{
  instances = {

    # Password generation via upstream clan-core users module.
    # Groups are set here; UID, shell, and SSH keys are in tags/all.nix.
    user-brittonr = {
      module = { name = "users", input = "clan-core" },
      roles.default = {
        tags.nixos = {},
        settings = {
          user = "brittonr",
          prompt = true,
          groups = [
            "wheel",
            "networkmanager",
            "video",
            "audio",
            "input",
            "kvm",
            "docker",
            "dialout",
            "disk",
          ],
        },
      },
    },

    # Home-manager profiles per machine group.
    # Server/headless machines: base + dev
    hm-server = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        tags.hm-server = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev"],
        },
      },
    },

    # Laptop machines: base + dev + noctalia + social
    hm-laptop = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        tags.hm-laptop = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev", "noctalia", "social"],
        },
      },
    },

    # Desktop: base + dev + noctalia + creative + social + media
    hm-desktop = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        machines.britton-desktop = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev", "noctalia", "creative", "social", "media"],
        },
      },
    },
  },
}
  | ValidateUserRefs
