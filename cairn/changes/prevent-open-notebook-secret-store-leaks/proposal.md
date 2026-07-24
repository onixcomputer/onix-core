## Why

The Open Notebook service schema accepts credential records containing API keys, then serializes those records into a `writeShellApplication` generator. Nix materializes that generated script in the world-readable store before Clan writes the nominally secret output, so an operator can leak bootstrap credentials even though the final `bootstrap-json` file is marked secret.

## What Changes

- Split non-secret Open Notebook provider/model metadata from secret credential material.
- Source API keys and other secret fields only from Clan-managed runtime secret files or prompts.
- Reject inline secret-bearing credential fields during module evaluation instead of embedding them in derivations.
- Add store-leak regression checks using sentinel credentials and runtime bootstrap tests.

## Impact

- **Files**: `modules/open-notebook/schema.ncl`, `modules/open-notebook/default.nix`, focused module checks, and operator documentation.
- **Risk**: Existing inline credential configurations will require an explicit migration to Clan secret inputs.
- **Non-goals**: Do not redesign Open Notebook's provider API or expose secrets through Nix environment variables.
- **Testing**: Evaluate positive non-secret metadata, reject inline secret values, inspect generated derivations for sentinel absence, and verify runtime secret assembly.
