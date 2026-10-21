## Where the exemption lives

Machines do not build radicle-node from their own package set. `inventory/tags/common/shared-nix.nix` overlays `radicle-node` and `radicle-httpd` with the flake packages from `flake-outputs/tools.nix`. adios-flake builds those from `import nixpkgs { inherit system; }` without a config. A machine's `nixpkgs.config.permittedInsecurePackages` therefore never reaches the package. Evaluating aspen3 with that setting still fails.

The flake package now comes from a second nixpkgs instance with `config.permittedInsecurePackages = [ "radicle-node-1.10.3" ]`. The setting only affects nixpkgs' meta check, so the derivation is the same one that `NIXPKGS_ALLOW_INSECURE=1` evaluates. Everything else in that instance stays unevaluated until something forces it.

## Creative-tag hosts

The `creative` tag sets `nixpkgs.config.allowInsecurePredicate`. nixpkgs consults that predicate instead of `permittedInsecurePackages`, so on aspen3 and britton-desktop a module-level `permittedInsecurePackages` entry has no effect. Scoping the exemption to the flake package avoids that interaction.

## Version bound

The exemption names `radicle-node-1.10.3`. When nixpkgs moves radicle-node, evaluation fails again until someone reviews the new version and the disclosure's status.

## Risks / Trade-offs

- Private repositories stay exposed to anyone on the network path and to a peer that claims an allow-listed node ID. Radicle advises stopping private seeding until the fix. The operator chose to keep seeding.
- Radicle's fix replaces the transport and breaks wire compatibility. All three nodes must upgrade together when it lands.
