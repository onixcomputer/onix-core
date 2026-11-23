# Clan instances of home-manager-profiles that reach aspen2
# (inventory/core/users.ncl:45-54, :80-94). profiles_base_path keeps its
# default, the path inventory/core/default.nix injects.
{
  hm-herdr-fleet = {
    service = "home-manager-profiles",
    roles.default = {
      machines = ["aspen1", "aspen2", "aspen3", "bonsai"],
      settings = { username = "brittonr", profiles = ["herdr"] },
    },
  },
  hm-server = {
    service = "home-manager-profiles",
    roles.default = {
      tags = ["hm-server"],
      settings = { username = "brittonr", profiles = ["base", "dev"] },
    },
  },
}
