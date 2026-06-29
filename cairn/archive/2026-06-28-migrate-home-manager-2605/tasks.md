## Phase 1: Inventory

- [x] [serial] r[onix.home-manager.2605.scope.inventory] Identify managed Home Manager users importing the shared Neovim profile.
- [x] [serial] r[onix.home-manager.2605.scope.state] Confirm the pre-migration effective `britton-desktop` Home Manager state version.

## Phase 2: Implementation

- [x] [serial] r[onix.home-manager.2605.scope.override] Add an explicit `26.05` Home Manager state-version override for `britton-desktop`.
- [x] [serial] r[onix.home-manager.2605.neovim.providers] Adopt the 26.05 Neovim provider defaults explicitly.

## Phase 3: Verification

- [x] [serial] r[onix.home-manager.2605.verify.effective_state] Verify the effective `britton-desktop` Home Manager state version is `26.05`.
- [x] [serial] r[onix.home-manager.2605.verify.neovim_providers] Verify the Neovim Ruby and Python providers are disabled.
- [x] [serial] r[onix.home-manager.2605.verify.negative_legacy] Verify the legacy state-version expectation is rejected by evaluated values.
- [x] [serial] r[onix.home-manager.2605.verify.system_eval] Verify focused `britton-desktop` system derivation evaluation succeeds.
- [x] [serial] r[onix.home-manager.2605.verify.cairn] Run Cairn validation for the repo.
