## Why

Move onix-core from Clan to OnixOS one machine at a time without losing anything a Clan deploy produces. The operator chose to port every Clan service to a typed Nickel OnixOS module, keep hosts on NixOS through OnixOS `mkFlake` with the Nix backend, turn Clan vars into OnixOS artifacts, and start with aspen2. Aspen2 ran native OnixOS from 2026-06-18 until it was reinstalled with NixOS through Clan on 2026-09-06 (`evidence/aspen2-nixos-install-2026-09-06.md`); this pilot keeps NixOS and changes only how the configuration is assembled.

## What Changes

- Assemble aspen2 through OnixOS beside Clan: `onixos.nixosConfigurations.aspen2` from `onixos/inventory.ncl`, whose machines are projected from `inventory/core/machines.ncl`. `nixosConfigurations` stays Clan's, and no Clan source or existing flake input changes.
- Port all 17 Clan service instances that reach aspen2 to 15 typed Nickel service modules under `onixos/services/`, with instances under `onixos/instances/`: users, home-manager-profiles, sshd (with its key companion openssh-keys), nix-gc, niks3, nix-build-farm, tailscale, prometheus, grafana, loki, arxiv-corpus, laya, mesh-llm, homepage-dashboard and borgbackup. Three artifact modules declare the vars generators that tag files define: nix-signing-key, nix-builder-ssh and berkeley-mono-font. Tag files, machine files and clan-core's base defaults stay NixOS modules (`onixos/nix/`).
- Copy aspen2's deployed Clan vars byte-identical into `onixos/secrets/` as OnixOS artifacts named like their generators.
- Add `onixos/tools/parity`, an `onixos-services` check for the Nickel module tests, an `onixos-<machine>` check per assembled machine, a runbook (`docs/onixos-aspen2-pilot.md`) and parity evidence.
- Depend on two OnixOS fixes on branch `onix-core-consumer`: identical shared artifact declarations merge, and record-form role machines evaluate under `builtins.wasm`.

## Impact

- **Files**: `flake.nix`/`flake.lock` (inputs `onix-modules`, `nixos-artifacts`), `flake-outputs/onixos.nix`, `flake-outputs/_onixos-checks.nix`, `flake-outputs/checks.nix`, `onixos/`, `docs/onixos-aspen2-pilot.md`.
- **Testing**: Nickel module tests, the inventory contract, evaluation of both aspen2 configurations, and a parity diff whose every difference is explained. No system is built or deployed.
- **Deployment prerequisites**: publish the OnixOS fixes and relock `onix-modules`; operator review of the parity evidence and runbook; then the cutover in the runbook. Until then aspen2 keeps deploying through Clan.
