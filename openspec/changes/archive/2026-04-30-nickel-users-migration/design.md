## Context

`inventory/core/users.nix` defines three service instances: one `users` instance (password/groups via clan-core) and three `home-manager-profiles` instances (server, laptop, desktop profile sets). The file is pure data — no NixOS module features, no `lib.*`, no package references.

The existing `services.ncl` migration established the pattern: data-only service instances in Nickel with contract validation, `.nix` files only for instances needing `extraModules`. `users.nix` fits the data-only pattern exactly.

The machine registry (`machines.ncl`) and service contracts (`services/contracts.ncl`) already validate tag and machine references. The user contracts can import these for cross-validation.

## Goals / Non-Goals

**Goals:**
- Move user instance definitions to `users.ncl` with contract validation
- Validate profile names against known profiles (base, dev, noctalia, creative, social, media)
- Validate tag references and machine references against existing registries
- Handle `profilesBasePath` (Nix path) by injecting it on the Nix side after evaluation

**Non-Goals:**
- Changing the user management architecture or adding new users
- Migrating `borgbackup.nix` or `matrix-synapse.nix` (they need `extraModules`)
- Modifying the home-manager-profiles module itself

## Decisions

**Users instances in a separate `users.ncl` rather than merging into `services.ncl`.** The core/services split matches how `default.nix` assembles the inventory — `inventory/core/` provides machines and user instances, `inventory/services/` provides service instances. Merging users into services would muddy that boundary. The contracts file in `inventory/core/contracts.ncl` already exists and is the natural home for user-specific validation.

**Profile name registry as a list in contracts.ncl.** Profile names (`base`, `dev`, `noctalia`, etc.) are validated against a static list in `contracts.ncl`, mirroring how tags are validated. This catches typos like `"devs"` or `"nocatlia"` at `ncl export` time. The list must be updated when adding new profiles — acceptable since adding a profile already requires creating a new directory and updating multiple configs.

**`profilesBasePath` stays on the Nix side.** Nickel can't produce Nix paths (they trigger store copies and carry string context). The `.ncl` file omits `profilesBasePath` from settings. The Nix glue in `default.nix` walks the evaluated instances and injects `profilesBasePath = ../home-profiles` into every `home-manager-profiles` instance's settings. This keeps the Nix path resolution where it belongs.

**Reuse `services/contracts.ncl` module registry pattern.** The user instances reference modules (`users`, `home-manager-profiles`) and inputs (`clan-core`, `self`). Rather than duplicating the module registry, `users.ncl` defines a local contract for the small set of modules it uses. Full cross-file module validation is deferred to the `validateNickel` change.

## Risks / Trade-offs

**Profile list drift.** If someone adds a profile directory without updating `contracts.ncl`, the Nickel validation will reject the new profile name. Mitigation: the error message names the valid profiles, making the fix obvious.

**`profilesBasePath` injection adds Nix-side complexity.** The glue code in `default.nix` needs to walk instances and patch settings. This is a few lines of `mapAttrs` — comparable to the existing `removeAttrs` for machine fields. The alternative (keeping users.nix for this one field) gives up all contract validation.
