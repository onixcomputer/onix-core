# Exported module lists for Nix flake checks.
#
# Extracts the serializable module name arrays from contracts.ncl.
# contracts.ncl itself can't be ncl-exported from Nix because it
# contains Nickel contracts (functions) that aren't JSON-serializable.
let contracts = import "contracts.ncl" in
let self_modules_raw = contracts.selfModules in
# selfModules might not be exported yet — read directly
{
  # Modules defined in modules/ (clan perInstance service definitions)
  selfModules = self_modules_raw,
}
