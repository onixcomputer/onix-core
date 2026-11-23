## ADDED Requirements

### Requirement: OnixOS assembly beside Clan

r[onix.onixos_migration.side_by_side] The flake MUST expose `onixos.nixosConfigurations.<machine>` for every machine ported to OnixOS, assembled by OnixOS `mkFlake` with the Nix backend from the same flake source. `nixosConfigurations` MUST stay Clan's until that machine's cutover. Porting MUST NOT change Clan's sources (`modules/`, `inventory/`, `machines/`, `vars/`, `sops/`, `flake-outputs/clan.nix`) or the locked source of any existing flake input.

#### Scenario: Clan build unchanged

- GIVEN the pilot branch and the commit it is based on
- WHEN `nixosConfigurations.aspen2.config.system.build.toplevel` is instantiated at both
- THEN the derivations differ only in the `configurationRevision` that each build reports

### Requirement: Typed service modules

r[onix.onixos_migration.typed_services] Every Clan service instance that reaches a ported machine MUST be an instance of a typed Nickel module under `onixos/services/`, declared under `onixos/instances/` with the Clan instance's name and settings. Tag files, machine files and clan-core's base defaults MUST stay NixOS modules imported through `extraNixosModules`. A module's Nix-side needs (upstream NixOS modules, overlays and evaluation order) MUST live in its sidecar `onixos/services/<name>.nix`.

#### Scenario: Module tests and inventory contract

- GIVEN the Nickel modules and the OnixOS inventory
- WHEN the `onixos-services` check runs
- THEN every module's tests pass
- AND the inventory satisfies the OnixOS `Inventory` contract

### Requirement: Secrets as OnixOS artifacts

r[onix.onixos_migration.secrets] Every vars file that Clan deploys to a ported machine MUST be an OnixOS artifact file with the Clan generator's name and file name, stored under `onixos/secrets/` as a byte-identical copy of the Clan file. Secret copies MUST list the machine's age key as a recipient. Evaluation of a ported machine MUST fail when a file it deploys as a sops secret is not a sops file encrypted to the machine's age key, without decrypting anything. Files that Clan does not deploy (`deploy = false`) MUST NOT be declared.

#### Scenario: Ciphertext custody

- GIVEN a ported secret file
- WHEN it is compared with its Clan vars file and its recipients are listed
- THEN it is byte-identical to its Clan vars file
- AND the machine's age public key is one of its recipients

#### Scenario: Unencrypted secret stops evaluation

- GIVEN a file deployed as a sops secret holds plaintext, or a sops file that is not encrypted to the machine's age key
- WHEN the machine's OnixOS configuration is evaluated
- THEN evaluation MUST fail with a message naming the secret and the reason

### Requirement: Explained parity

r[onix.onixos_migration.parity] `onixos/tools/parity <machine>` MUST compare the Clan and OnixOS toplevel derivations of a machine from the same flake source. Every differing derivation MUST be listed with its reason in the change's parity evidence before the machine is cut over.

#### Scenario: Parity run

- GIVEN a ported machine
- WHEN the parity tool runs
- THEN every differing derivation it reports appears in the parity evidence with a reason

### Requirement: Reviewed cutover

r[onix.onixos_migration.cutover] A ported machine MUST NOT be deployed from its OnixOS configuration before the operator has reviewed its parity evidence and runbook. The cutover MUST point `nixosConfigurations.<machine>` at the OnixOS configuration, deploy it through `onix deploy`, and keep the previous NixOS generation as the rollback.

#### Scenario: Deploy plan without host contact

- GIVEN the OnixOS inventory
- WHEN `onix deploy --dry-run aspen2` runs
- THEN it prints the build, copy and activation plan without contacting aspen2

### Requirement: Mantle build without deploy

r[onix.onixos_migration.mantle_build] The ported machine's typed services MUST build with the Mantle backend without running a Nix program, and the resulting artifact MUST pass a Mantle deploy dry-run. The artifact MUST NOT be deployed to the machine while its activation entrypoints do not apply the services.

#### Scenario: Mantle build with Nix programs stubbed

- GIVEN Nix programs replaced on `PATH` by stubs that log each call and fail
- WHEN `onix build --backend mantle aspen2` runs with the unwrapped `onix-cli`
- THEN the build reports `built` with one `mantle-onix-activation-closure` artifact covering all 24 typed units
- AND no stub was called

#### Scenario: Deploy dry-run accepts the proof

- GIVEN that build report
- WHEN `onix deploy --dry-run --backend mantle --mantle-build-report <report> aspen2` runs
- THEN it accepts the deployability proof without contacting aspen2
- AND the runbook records that the artifact's activation only checks its payload manifest
