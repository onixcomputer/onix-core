# Remote builder targets — validated against the machine registry.
#
# Consumed by remote-builders.nix. Cross-references machine names
# to catch typos at `ncl export` time.
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
    {
      # r[impl onix.remote_builder.routing.aspen]
      name = "aspen1",
      speedFactor = 20,
      systems = ["x86_64-linux"],
      sshUser = "root",
      sshHost = "aspen1.local",
      maxJobs = 16,
      supportedFeatures = ["nixos-test", "big-parallel", "kvm"],
    },
    # aspen2 removed — it and aspen1 were each other's remote builders,
    # causing nix to dispatch the same derivations in both directions.
    # aspen1 is the dedicated build server; aspen2 offloads to it.
  ],
} | Contracts.BuilderTargets
