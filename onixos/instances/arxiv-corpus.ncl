# Clan instance arxiv-aspen2 (inventory/services/services.ncl): aspen2 only,
# bound to its Tailscale address (mesh_aspen2_address).
{
  arxiv-aspen2 = {
    service = "arxiv-corpus",
    roles.server.machines.aspen2.settings.host = "100.82.25.30",
  },
}
