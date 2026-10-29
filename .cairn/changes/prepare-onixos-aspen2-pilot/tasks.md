## Phase 1: Framework

- [x] [serial] Add the `onix-modules` and `nixos-artifacts` inputs and `flake-outputs/onixos.nix`, exposing `onixos.nixosConfigurations.aspen2` beside Clan's configurations. r[onix.onixos_migration.side_by_side]
- [x] [serial] Project machines from `inventory/core/machines.ncl` into `onixos/inventory.ncl`, and import tag files, machine files and clan-core's base defaults as NixOS modules in Clan's order. r[onix.onixos_migration.typed_services]
- [x] [serial] Add sidecars, the vars compatibility module and the package overlays. r[onix.onixos_migration.typed_services]
- [x] [serial] Fix the two OnixOS defects the pilot hit on OnixOS branch `onix-core-consumer`: identical shared artifact declarations (`713d5d15`) and record-form role machines under `builtins.wasm` (`2d23df26`). r[onix.onixos_migration.side_by_side]

## Phase 2: aspen2 port

- [x] [parallel] Port the 17 Clan service instances that reach aspen2 to typed Nickel modules with tests, and declare the three tag-file generators as artifact modules. r[onix.onixos_migration.typed_services]
- [x] [parallel] Copy aspen2's deployed vars files byte-identical into `onixos/secrets/` and check that every secret copy lists aspen2's age key. r[onix.onixos_migration.secrets]

## Phase 3: Verification

- [x] [serial] Add `onixos/tools/parity`, the `onixos-services` check and an `onixos-<machine>` check per assembled machine. r[onix.onixos_migration.parity]
- [x] [serial] Run the Nickel module tests and the inventory contract. r[onix.onixos_migration.typed_services]
- [x] [serial] Run the parity diff for aspen2 and record every difference with its reason in `parity-evidence.json`. r[onix.onixos_migration.parity]
- [x] [serial] Compare Clan's aspen2 derivation at the pilot commit with the base commit. r[onix.onixos_migration.side_by_side]
- [x] [serial] Compare the sops manifests after renaming and the secret copies with `vars/`. r[onix.onixos_migration.secrets]
- [x] [serial] Print the deploy plan with `onix deploy --dry-run aspen2` and write the runbook `docs/onixos-aspen2-pilot.md`. r[onix.onixos_migration.cutover]
- [x] [serial] Run the formatter on the changed files and validate Cairn. r[onix.onixos_migration.parity]

## Phase 4: Cutover

- [ ] [serial] Operator review of the parity evidence, the runbook and the gaps. r[onix.onixos_migration.cutover]
- [ ] [serial] Publish OnixOS branch `onix-core-consumer`, relock `onix-modules`, and rerun parity without `--override-input`. r[onix.onixos_migration.parity]
- [ ] [serial] Point `nixosConfigurations.aspen2` at the OnixOS build and deploy it with `onix deploy`, first with `--action test`. r[onix.onixos_migration.cutover]

No host was contacted and no system was built. aspen2 still deploys through Clan.
