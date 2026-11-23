# Clan instance mesh-llm-private-inference (inventory/services/services.ncl).
# aspen2 is a research-only joiner. aspen1 (seed), aspen3 (joiner) and
# britton-desktop (joiner, research forwarder with gateway) stay on Clan;
# their modes are the peer facts Clan read through `roles`.
{
  mesh-llm-private-inference = {
    service = "mesh-llm",
    roles.default = {
      settings.mesh_nodes = {
        aspen1 = "seed",
        aspen2 = "joiner",
        aspen3 = "joiner",
        britton-desktop = "joiner",
      },
      machines.aspen2.settings = {
        mode = "joiner",
        # No local inference backend; aspen2 provides research tools only.
        endpoint_url = null,
        mesh_bind_address = "100.82.25.30",
        research_mode = "provider",
        research_arxiv_address = "100.82.25.30:7998",
        research_laya_address = "100.82.25.30:7999",
        research_backend_units = ["arxiv-corpus-arxiv-aspen2.service", "laya-laya-aspen2.service"],
      },
    },
  },
}
