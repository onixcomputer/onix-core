## Why

`britton-desktop` currently inherits `home.stateVersion = "25.11"` from `system.stateVersion`. Home Manager now warns that upcoming 26.05 defaults for Neovim Ruby and Python providers differ from the legacy defaults preserved by older state versions. Silencing one warning option-by-option keeps evaluation quiet, but it does not make the intended Home Manager compatibility boundary explicit.

## What Changes

- Migrate the `britton-desktop` Home Manager state version to `26.05` intentionally.
- Adopt the Home Manager 26.05 Neovim provider defaults unless the profile explicitly opts back into a provider.
- Add focused validation that confirms the effective Home Manager state version and Neovim provider choices for `britton-desktop`.

## Impact

- **Files**: `cairn/changes/migrate-home-manager-2605/**`, `inventory/home-profiles/brittonr/base/neovim.nix`, and the Home Manager profile/inventory wiring that sets the effective state version for `britton-desktop`.
- **Testing**: Cairn validation plus focused Nix evals for `britton-desktop` state-version/provider values and the system toplevel derivation.
