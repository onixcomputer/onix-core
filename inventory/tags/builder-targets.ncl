# Remote builder targets — validated against the machine registry.
#
# Consumed by remote-builders.nix. Cross-references machine names
# to catch typos at `ncl export` time.
# Managed Linux builds use the nix-build-farm service. This list retains
# independent SSH targets; do not add farm workers here and recreate cycles.
let machines_data = import "../core/machines.ncl" in
let machine_names = std.record.fields machines_data.machines in
let Contracts = (import "builder-target-contracts.ncl") machine_names in

{
  targets = [
    {
      name = "britton-air",
      speedFactor = 12,
      # britton-air is the Darwin host. Its nested `linux-builder` VM can
      # build aarch64-linux when a build is launched on britton-air, but this
      # top-level SSH endpoint must not advertise Linux directly.
      # It is also not currently reachable from the NixOS clients that consume
      # remote-builders, so keep it out of generated remote builder lists until
      # a routable endpoint is declared and validated.
      allowedConsumers = [],
      systems = ["aarch64-darwin"],
      sshUser = "brittonr",
      maxJobs = 16,
      supportedFeatures = ["big-parallel"],
    },
  ],
} | Contracts.BuilderTargets
