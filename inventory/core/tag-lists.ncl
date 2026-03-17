# Exported tag lists for Nix flake checks.
#
# Extracts the serializable tag arrays from contracts.ncl.
# contracts.ncl itself can't be evaluated from Nix because it
# contains Nickel contracts (functions) that aren't JSON-serializable.
let contracts = import "contracts.ncl" in
{
  tagFileTags = contracts.tagFileTags,
  autoTagsWithFiles = contracts.autoTagsWithFiles,
}
