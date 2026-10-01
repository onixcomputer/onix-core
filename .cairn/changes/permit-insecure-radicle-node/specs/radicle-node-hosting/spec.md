# Radicle Node Hosting Specification Delta

## ADDED Requirements

### Requirement: Exact insecure-package exemption for radicle-node

r[onix.radicle_node.insecure_exemption] `onix-core` MUST exempt exactly `radicle-node-1.10.3` from nixpkgs' insecure-package refusal where the flake builds its `radicle-node` package, and Radicle hosts MUST receive radicle-node from that package. The exemption MUST NOT cover other packages or versions.

#### Scenario: Radicle hosts evaluate with the marked package

r[onix.radicle_node.insecure_exemption.admitted]
- GIVEN nixpkgs marks `radicle-node-1.10.3` insecure
- WHEN the aspen1, britton-desktop and aspen3 toplevels are evaluated
- THEN evaluation succeeds
- AND the exempted package builds

#### Scenario: Another radicle-node version needs review

r[onix.radicle_node.insecure_exemption.version_bound]
- GIVEN nixpkgs marks a radicle-node version other than `1.10.3` insecure
- WHEN a Radicle host is evaluated
- THEN evaluation fails until the exemption names that version
