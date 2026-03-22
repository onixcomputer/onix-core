## 1. Add user/profile contracts to contracts.ncl

- [x] 1.1 Add `profile_names` list (`["base", "dev", "noctalia", "creative", "social", "media"]`) to `inventory/core/contracts.ncl`
- [x] 1.2 Add `ProfileName` contract that validates a string is in `profile_names`
- [x] 1.3 Tag and machine validation handled by `ValidateUserRefs` contract in `users.ncl` (reuses same pattern as `services/contracts.ncl`)
- [x] 1.4 Machine validation uses `machines.ncl` import to get `machine_names`
- [x] 1.5 Export `profileNames` so `users.ncl` can import it via `contracts.ncl`

## 2. Create users.ncl

- [x] 2.1 Create `inventory/core/users.ncl` with all four instance groups: `user-brittonr`, `hm-server`, `hm-laptop`, `hm-desktop`
- [x] 2.2 Profile name validation via `ValidateUserRefs` contract checking against `contracts.profileNames`
- [x] 2.3 Tag validation via `ValidateUserRefs` contract checking against `all_service_tags`
- [x] 2.4 Machine validation via `ValidateUserRefs` contract checking against `machine_names` from `machines.ncl`
- [x] 2.5 `profilesBasePath` omitted from all settings
- [x] 2.6 `ncl export inventory/core/users.ncl` succeeds and produces expected structure

## 3. Update Nix glue in default.nix

- [x] 3.1 In `inventory/core/default.nix`, load `users.ncl` via `wasm.evalNickelFile ./users.ncl`
- [x] 3.2 `profilesBasePath` injection: `mapAttrs` walks instances, checks `module.name == "home-manager-profiles"`, injects `profilesBasePath = ../home-profiles` into each role's settings
- [x] 3.3 Deleted `inventory/core/users.nix`

## 4. Verify build

- [x] 4.1 Verified via `nix eval` that inventory produces correct instances with `profilesBasePath` injected on hm-* instances and absent on user-brittonr
- [x] 4.2 Verified contracts catch typos: `"baze"` → error naming invalid profile; `"britton-desktoppp"` → error naming invalid machine
