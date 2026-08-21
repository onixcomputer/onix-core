# This fixture must fail because an explicit SSH host cannot be empty.
let Contracts = (import "../builder-target-contracts.ncl") ["aspen1"] in
{
  targets = [
    {
      name = "aspen1",
      speedFactor = 1,
      systems = ["x86_64-linux"],
      sshUser = "root",
      sshHost = "",
      maxJobs = 1,
      supportedFeatures = ["big-parallel"],
    },
  ],
} | Contracts.BuilderTargets
