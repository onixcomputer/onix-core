# Exported builder registry for Nix consumption.
#
# Extracts the builderHosts mapping from contracts.ncl.
# Used by remote-builders.nix to filter self from buildMachines.
let contracts = import "contracts.ncl" in
{
  builderHosts = contracts.builderHosts,
}
