# Clan instance store-maintenance (inventory/services/services.ncl).
{
  store-maintenance = {
    service = "nix-gc",
    roles.default = {
      tags = ["nixos"],
      settings = {
        retention_days = 30,
        schedule = "weekly",
        optimize_store = true,
        auto_optimise = true,
      },
    },
  },
}
