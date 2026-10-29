# Design: Prepare aspen2 to move from Clan to OnixOS

## Context

onix-core assembles every machine with Clan: clan-core's base modules, one importer instance per `inventory/tags/<tag>.nix`, the machine directory, and Clan service instances from `inventory/services/services.ncl` and `inventory/core/users.ncl`, with secrets from `vars/`. OnixOS's `mkFlake` evaluates a Nickel inventory and typed Nickel service modules, assembles NixOS systems with the Nix backend, deploys them with `onix deploy`, and manages secrets as artifacts through sops-nix. The operator chose typed Nickel modules for every Clan service, NixOS hosts built by `mkFlake`, Clan vars turned into OnixOS artifacts, and aspen2 as the first machine.

## Decisions

### Decision: Build OnixOS beside Clan from one source

`flake-outputs/onixos.nix` calls `mkFlake` with `onixos/inventory.ncl` and exposes only the assembled machines as `onixos.nixosConfigurations`. The inventory projects every NixOS machine from `inventory/core/machines.ncl`, so machine data has one source. `nixosConfigurations` stays Clan's, so Clan deploys are unchanged and `onixos/tools/parity` can compare both builds of a machine from the same commit. The pilot adds the inputs `onix-modules` and `nixos-artifacts` and changes no other locked input.

### Decision: Services in onix-core, tags and machines as NixOS modules

The service modules live in `onixos/services/`, not in OnixOS's `modules/`: they encode this fleet's services, and keeping them here avoids an OnixOS release per service change. They replace OnixOS's modules of the same name for onix-core. Each module keeps its Clan instance's settings and defaults, and `tests` cover the aspen2 settings and the module's branches. Tag files, machine files and clan-core's base defaults stay NixOS modules through `extraNixosModules` (`onixos/nix/machines.nix`, `clan-carryover.nix`): they are host configuration rather than services, and reusing them unchanged keeps Clan and OnixOS builds of a machine identical where nothing was ported.

### Decision: Nix-side needs in sidecars

Nickel cannot import NixOS modules, build packages or name store paths, and a module cannot read public artifacts that it declares itself. A service with such needs has a sidecar `onixos/services/<name>.nix` listing upstream NixOS modules, package overlays and the modules it must follow (`onixos/nix/service-sidecars.nix`). Where Clan wrote a store path into a unit or file, the port uses an equivalent that Nickel can express: a unit `script` or `preStart` with the package in `path`, a file under `/etc` referenced by path, or a lookup through `PATH`. Moved configuration files keep a restart trigger.

### Decision: Clan's module order

List-valued options merge in module order, so assembly follows Clan's order where the parity diff showed it matters: tag files sorted by their Clan instance name (`base-settings`, `<tag>-tools`), sidecar modules at the depth where a Clan service imports its upstream modules, and Home Manager profile instances merged in the order Clan's per-instance modules produce. Remaining order differences inside lists are listed in the parity evidence; none changes a set or a setting.

### Decision: Secrets keep their Clan names and ciphertexts

An artifact has the Clan generator's name and file names, and `onixos/secrets/` holds byte-identical copies of the Clan files, so no secret is decrypted or re-encrypted and aspen2's existing age key decrypts them. The runtime path changes from `/run/secrets/vars/per-machine/aspen2/<generator>/<file>` and `/run/secrets/vars/shared/<generator>/<file>` to `/run/secrets/<generator>/<file>`; every consumer follows the new path. `onixos/nix/clan-vars-compat.nix` maps the `clan.core.vars.generators` paths that tag files read to the same sops secrets. Files Clan does not deploy (the SSH CA key, the plaintext user password, the build farm CA key) are not declared, because OnixOS deploys every declared secret.

### Decision: Clan backup-provider plumbing is not ported

clan-core's `clan.core.state` registry, its `state-commands` package, the borg job's pre/post-backup hook runners and the `borgbackup-create`, `borgbackup-list` and `borgbackup-restore` helpers serve the `clan backups` command. No onix-core state defines a hook script, so the runners were no-ops on aspen2. The borg job, its timer, wrapper, paths, excludes and NetworkManager wait are ported unchanged.

### Decision: OnixOS fixes before relocking

Two OnixOS defects blocked the pilot and are fixed on OnixOS branch `onix-core-consumer`: identical shared artifact declarations from several machines collided (`713d5d15`), and record-form role machines (`machines.<name>.settings`) aborted under `builtins.wasm` (`2d23df26`). Until that branch is published and `onix-modules` relocked, evaluation needs `--override-input onix-modules git+file://<checkout>`.

### Decision: Cutover through nixosConfigurations

`onix deploy --backend nix` builds `.#nixosConfigurations.<machine>.config.system.build.toplevel`, so a machine's cutover points that attribute at `onixos.nixosConfigurations.<machine>`. `clan.nixosConfigurations` keeps Clan's build for parity and rollback. The runbook (`docs/onixos-aspen2-pilot.md`) describes the steps.

## Risks / Trade-offs

- Secret paths change, so every unit that names a secret restarts on the first OnixOS switch, including sshd and nix-daemon. Safe mode reverts the switch if the deploy SSH session cannot confirm.
- Activation-time secrets and `deploy = false` files still come from Clan. OnixOS cannot yet keep generated but undeployed secrets, upload activation secrets, or order generators by their dependencies, so rotating those secrets needs Clan.
- OnixOS prompts have no hidden or persist flags, so regenerating a prompted secret behaves differently from Clan.
- `system.stateVersion` still comes from `vars/per-machine/<machine>/state-version`.
- Roles that run on other machines are not ported: the niks3 server, the build farm scheduler, balancer and clients, the borg server, the mesh-llm seed and forwarder, laya's Vulkan instance and the other Home Manager instances.
- mesh-llm now starts its research plugin by name through `PATH`; [INFERENCE] mesh-llm spawns plugins with a `PATH` lookup, which no test here exercises.

## Verification

Nickel module tests and the inventory contract (`onixos-services` check), the parity diff of aspen2 with every difference explained (`parity-evidence.json`), the Clan build compared with the base commit, the deploy plan from `onix deploy --dry-run`, the formatter on all changed files, and Cairn validation.
