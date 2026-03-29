## Why

Service instances in `services.ncl` validate module names, tag references, and machine references via Nickel contracts — but the `settings` records inside each role are completely freeform (`{ _ : Dyn }`). A typo like `enableGPu = true` or `prot = 8080` passes `ncl export` silently and only fails at NixOS build time minutes later (or worse, gets silently ignored by freeformType modules). With ~25 service instances containing structured settings, this is the largest surface area of unvalidated data in the inventory.

## What Changes

- Add per-service settings contracts in Nickel that validate the shape and types of settings records at `ncl export` time
- Create a settings contract registry that maps `(module-name, role-name)` pairs to their expected settings shape
- Wire the contracts into the existing `services.ncl` validation pipeline so settings are checked alongside tag/machine refs
- Settings contracts use open records (allow extra fields) so NixOS-side defaults and extensions still work — the contracts catch typos and type mismatches, not completeness

## Capabilities

### New Capabilities
- `settings-contracts`: Per-service Nickel contracts that validate settings records in service inventory roles, catching typos and type errors at `ncl export` time

### Modified Capabilities

## Impact

- `inventory/services/contracts.ncl` — extended with settings validation logic and contract registry
- `inventory/services/services.ncl` — may need minor structural changes if the validator needs to see settings alongside module info
- New file(s) for the per-service contract definitions (one file or split per service group)
- Existing `ncl export` workflow gains settings validation — no changes to the Nix consumption side
