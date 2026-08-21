# Production DGX machine inventory.
#
# Keep this map empty until real names, targets, storage identities, hardware
# reports, SSH host keys, SOPS files, and Mesh-LLM backend ownership exist.
let { DgxMachines, .. } = import "contracts.ncl" in

{
  machines = {},
} | DgxMachines
