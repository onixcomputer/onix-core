# Clan instance laya-aspen2 (inventory/services/services.ncl): cpu backend on
# aspen2's Tailscale address. laya-aspen1 (vulkan) and laya-aspen3 stay on Clan.
{
  laya-aspen2 = {
    service = "laya",
    roles.server.machines.aspen2.settings.host = "100.82.25.30",
  },
}
