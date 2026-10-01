## Implementation

- [x] [serial] Build the flake `radicle-node` package from a nixpkgs instance that permits exactly `radicle-node-1.10.3`. r[onix.radicle_node.insecure_exemption]
- [x] [serial] Record the package ownership and the `creative` predicate precedence in `AGENTS.md`. r[onix.radicle_node.insecure_exemption]

## Verification

- [x] [serial] Evaluate the aspen1, britton-desktop and aspen3 toplevels, and build the exempted package. r[onix.radicle_node.insecure_exemption.admitted]
- [x] [serial] Confirm that the same package set still refuses radicle-node 1.10.4. r[onix.radicle_node.insecure_exemption.version_bound]
- [x] [serial] Run Cairn validation. r[onix.radicle_node.insecure_exemption]

## Deployment

- [ ] [serial] Deploy aspen3, britton-desktop and aspen1 with `clan machines update`. r[onix.radicle_node.insecure_exemption.admitted]
