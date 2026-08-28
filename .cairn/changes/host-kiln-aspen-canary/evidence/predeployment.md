# Pre-deployment verification

Date: 2026-08-28

## Verdict

PASS for package, profile, module, machine-evaluation, formatting, and Cairn pre-deployment gates.

Live private-host observations are not included. This evidence does not authorize archive or stable promotion.

## Exact dependency cohort

- Kiln deployable host: `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`
- Kiln hosted protocol: `42eabcb21385a436ddc044fb7034b8cdaec7b8a0`
- Aspen materialized completion: `22f8ded26ca1907c29948e08b53f35df23080733`
- Lattice application: `c513d94d89e901ffa56ae67f375f973e55958e42`
- Lattice workflow contract: `70496e67c7fd4a8b05914161a8e09de2759bebc8`
- Bounded Exec: `29dac88ecded94457572db3fdfaaaab95fa91525`

Nix generated the final Kiln lock update from `flake.nix`. The module check verifies the exact Kiln input revision and the internal hosted-protocol revision.

## Checks

| Check | Result | Observation |
|---|---|---|
| `nix build path:$PWD#checks.x86_64-linux.kiln-aspen-canary-profiles --no-link -L --builders ''` | PASS | Typed positive profiles exported and all negative fixtures failed as required. |
| `nix build path:$PWD#checks.x86_64-linux.kiln-aspen-canary-module --no-link -L --builders ''` | PASS | The unoverridden host, Kiln adapter, Lattice application, service authority, no-fallback commands, uncertainty command, and existing route checks passed. |
| `nix eval path:$PWD#nixosConfigurations.britton-desktop.config.system.build.toplevel.drvPath --raw --option allow-import-from-derivation true` | PASS | The full `britton-desktop` system produced a derivation path. Existing unrelated inventory and deprecation warnings remain. |
| `nixfmt --check` on changed Nix files | PASS | Focused Nix formatting is clean. |
| `nickel format --check` on changed inventory and module files | PASS | Focused Nickel formatting is clean. |
| `nickel typecheck` on the changed service inventory files | PASS | Service contracts, settings contracts, and inventory typecheck. |
| Cairn strict validation with the generated policy | PASS | 18 active changes and 46 accepted or delta specs validate without issues. |

## Corrective findings

The first complete module build found two pre-deployment defects:

1. ShellCheck rejected an unused socket-readiness loop variable. Both loops now use the explicit ignored binding `_attempt`.
2. Nix evaluation overflowed while `lib.hasInfix` scanned the large standalone `Cargo.lock`. The check now performs the exact revision search inside the bounded derivation shell.

The final module build passed after both fixes.

`nix develop path:$PWD` could not determine the Devenv working directory in this linked worktree. The already installed pinned Nickel executable ran the same focused format and type checks successfully.

## Remaining gate

Deployment and the accepted, rejected, unavailable, uncertainty, restart, replay, reconciliation, and explicit rollback drills remain required.

Process-local journals and callback values do not prove durable active-operation recovery. No production, availability, CI-correctness, workflow-correctness, sandbox, or external-effect claim is made.
