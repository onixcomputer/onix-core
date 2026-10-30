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
- [x] [serial] Check every `onixos/secrets` file without decrypting it, and scan the unpushed commits of both branches for secret material. r[onix.onixos_migration.secrets]
  - 2026-10-29: 18 secret copies are sops binary envelopes with AES-256-GCM data and MAC and only age recipients, aspen2 among them; 6 public copies are SSH public keys, the SSH host certificate and the 32-byte Nix signing public key. gitleaks 8.30.1 found nothing in the 2 unpushed onix-core and 2 OnixOS commits, and flagged a throwaway private key in a scratch repository.
- [x] [serial] Fail evaluation when a deployed sops secret is not encrypted to its machine (`onixos/nix/encrypted-secrets.nix`), and run the commit hooks (treefmt, statix, deadnix) on every changed file. r[onix.onixos_migration.secrets]
  - 2026-10-29: the check accepts aspen2's 18 secrets and rejects plaintext, unencrypted JSON, plaintext data in a sops envelope, aspen3's ciphertext and a non-JSON format, each with its reason; a scratch commit with one plaintext secret fails evaluation. statix's repeated-key warnings in `clan-carryover.nix` were fixed without changing a value.
- [x] [serial] Print the deploy plan with `onix deploy --dry-run aspen2` and write the runbook `docs/onixos-aspen2-pilot.md`. r[onix.onixos_migration.cutover]
- [x] [serial] Run the formatter on the changed files and validate Cairn. r[onix.onixos_migration.parity]

## Phase 4: Cutover

- [ ] [serial] Operator review of the parity evidence, the runbook and the gaps. r[onix.onixos_migration.cutover]
- [x] [serial] Publish OnixOS branch `onix-core-consumer`, pin `onix-modules` to it, and rerun parity without `--override-input`. r[onix.onixos_migration.parity]
  - 2026-10-29: branch published at `2d23df26`; only the `onix-modules` lock node changed; parity at `09a64d3d` lists the same 31 derivations with the same hash-normalized differences as the run with the override.
- [x] [serial] Land the fixes on OnixOS `main`, drop `?ref=` from `onix-modules`, relock, and rerun parity. r[onix.onixos_migration.parity]
  - 2026-10-30: 113 of OnixOS's 299 checks passed at `2d23df26`, among them 3,913 CLI cargo tests, 100 WASM eval checks, shim-unit, Nickel, formatting, Cairn and the `onix` package; all 299 evaluate, and the other 186 were not built for lack of disk space on every reachable build host. The operator approved landing on these. OnixOS `main` fast-forwarded from `539430c3` to `2d23df26` without force; `onix-modules` is locked to `main` at `2d23df26`, and parity at `a2a7d5e5` lists the same 31 derivations with the same hash-normalized differences.
- [ ] [serial] Point `nixosConfigurations.aspen2` at the OnixOS build and deploy it with `onix deploy`, first with `--action test`. r[onix.onixos_migration.cutover]

No host was contacted and no system was built. aspen2 still deploys through Clan.
