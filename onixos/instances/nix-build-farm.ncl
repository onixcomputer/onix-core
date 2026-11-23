# Clan instance nix-build-farm (inventory/services/services.ncl): node role.
# The balancer (aspen1) and client roles (bonsai, aspen3, britton-desktop)
# are not ported.
let node = fun node_address scheduler =>
  {
    settings = {
      address = node_address,
      is_scheduler = scheduler,
      scheduler_address = if scheduler then "" else "100.100.103.95:50052",
    },
  }
in
{
  nix-build-farm = {
    service = "nix-build-farm",
    roles.node = {
      settings = {
        port = 50052,
        max_jobs = 16,
        min_free = "100G",
        cache_url = "http://100.100.103.95:39400",
        cache_instance = "nix-cache",
        # vars/shared/niks3-nix-cache-storage/signing-key-public/value
        cache_public_key = "onix-niks3-1:1Vg2qs7firQQJ/08DpDIXVBY41v6gPbHuwQlqr7EoQU=",
        allowed_clients = ["bonsai", "aspen3", "britton-desktop"],
        worker_names = ["aspen1", "aspen2"],
        balancer_names = ["aspen1"],
      },
      machines = {
        aspen1 = node "100.100.103.95" true,
        aspen2 = node "100.82.25.30" false,
      },
    },
  },
}
