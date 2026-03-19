# Remote builder targets — validated against the machine registry.
#
# Consumed by remote-builders.nix. Cross-references machine names
# to catch typos at `ncl export` time.
let machines_data = import "../core/machines.ncl" in
let machine_names = std.record.fields machines_data.machines in

let ValidMachineName =
  std.contract.from_validator (fun name =>
    if std.array.elem name machine_names then
      'Ok
    else
      'Error {
        message = "unknown machine: \"%{name}\"",
        notes = ["Valid machines: %{std.string.join ", " machine_names}"],
      }
  )
in

let PositiveNum =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let BuilderTarget = {
  name | ValidMachineName,
  speedFactor | PositiveNum,
  systems | Array String,
  sshUser | String,
  maxJobs | PositiveNum,
  supportedFeatures | Array String,
}
in

{
  targets | Array BuilderTarget = [
    {
      name = "britton-air",
      speedFactor = 12,
      systems = ["aarch64-darwin", "aarch64-linux"],
      sshUser = "brittonr",
      maxJobs = 16,
      supportedFeatures = ["big-parallel"],
    },
    {
      name = "aspen1",
      speedFactor = 20,
      systems = ["x86_64-linux"],
      sshUser = "root",
      maxJobs = 16,
      supportedFeatures = ["nixos-test", "big-parallel", "kvm"],
    },
    {
      name = "aspen2",
      speedFactor = 20,
      systems = ["x86_64-linux"],
      sshUser = "root",
      maxJobs = 16,
      supportedFeatures = ["nixos-test", "big-parallel", "kvm"],
    },
  ],
}
