## Why

`inventory/core/users.nix` defines user instances and home-manager profile assignments as pure data attrsets with no Nix-specific logic. It's the same service-instance schema that `services.ncl` already validates with Nickel contracts. Without migration, typos in profile names, tag references, or machine references silently produce broken configs that only fail at NixOS build time.

The one complication is `profilesBasePath = ../home-profiles` — a Nix path that triggers store copy. This can't be expressed in Nickel. The Nix glue layer must inject it after Nickel evaluation.

## What Changes

- Move user and home-manager profile instance definitions from `inventory/core/users.nix` to a new `inventory/core/users.ncl`
- Add Nickel contracts validating profile names against a known list, tag references against the tag registry, machine references against the machine registry, and module names against a module list
- Update `inventory/core/default.nix` to consume `users.ncl` via `evalNickelFile` and inject `profilesBasePath` on the Nix side
- Delete `inventory/core/users.nix`

## Capabilities

### New Capabilities
- `nickel-users-contracts`: Nickel contracts for user and home-manager profile instances — validating profile names, tag references, machine references, module names, and group names at `ncl export` time

### Modified Capabilities
- `nickel-eval`: The existing Nickel evaluation capability handles users.ncl identically to services.ncl — no requirement change, just a new consumer

## Impact

- `inventory/core/users.ncl` — new file
- `inventory/core/contracts.ncl` — extended with user/profile contracts and profile name registry
- `inventory/core/default.nix` — updated glue to load users.ncl and inject profilesBasePath
- `inventory/core/users.nix` — deleted
- `inventory/services/contracts.ncl` — may import profile-related contracts for cross-validation
