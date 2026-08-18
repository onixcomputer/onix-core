## Context

The `home-manager-profiles` service currently assigns `home.stateVersion = lib.mkDefault config.system.stateVersion` for every managed user. On `britton-desktop`, the pre-migration effective Home Manager state version evaluated to `25.11`, so Home Manager preserved pre-26.05 defaults for options whose defaults changed. Neovim reported that `programs.neovim.withRuby` and `programs.neovim.withPython3` would default to `false` for `home.stateVersion >= "26.05"`, while the legacy default remained `true`.

The shared `brittonr/base` Home Manager profile imports `neovim.nix`. Inventory assignments that include `base` are `hm-server`, `hm-laptop`, and `hm-desktop`; only `hm-desktop` is machine-scoped directly to `britton-desktop` for this migration.

## Decisions

### 1. Scope the migration to `britton-desktop` Home Manager

**Choice:** Add an explicit Home Manager state-version override for the `britton-desktop` user/profile assignment instead of bumping all machines through `system.stateVersion`.

**Rationale:** `home.stateVersion` changes compatibility defaults for user-level programs. Scoping the change to `britton-desktop` keeps the workstation migration independent from NixOS `system.stateVersion` and avoids changing headless machines or laptops without auditing them.

### 2. Adopt 26.05 Neovim provider defaults

**Choice:** Set `programs.neovim.withRuby = false` and `programs.neovim.withPython3 = false` in the shared base Neovim profile.

**Rationale:** The migration should adopt the new Home Manager behavior intentionally rather than carrying the legacy providers forward by accident. Keeping the values explicit documents the choice and prevents future default-change warnings from obscuring operator intent.

### 3. Verify effective values through Nix evaluation

**Choice:** Validate the migration by evaluating `britton-desktop`'s effective Home Manager state version, Neovim provider options, and system derivation path.

**Rationale:** Focused Nix evals prove the pure configuration values without requiring a full deploy. The final system derivation eval catches module-level regressions and confirms the Neovim migration warnings are gone.

## Risks / Trade-offs

- Neovim plugins or local workflows that rely on Ruby or Python provider support may need explicit opt-in later.
- A shared base Neovim profile means provider defaults change for any other managed Home Manager user that imports the profile. Current usage should be checked before final validation.
- Leaving `system.stateVersion` at `25.11` is intentional; this is a Home Manager migration, not a NixOS state migration.
