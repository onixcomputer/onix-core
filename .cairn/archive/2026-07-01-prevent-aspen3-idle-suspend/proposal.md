## Why

`aspen3` is now serving large local LLM downloads and inference through Lemonade, but its interactive Noctalia profile inherits the shared `swayidle` chain that runs `systemctl suspend` after the idle suspend timeout. During long remote model pulls or loads, no local input may occur, so the machine can suspend and disappear from the network mid-operation.

## What Changes

- Add a Home Manager option that lets the Noctalia idle service omit the suspend timeout while preserving screensaver, dimming, and DPMS monitor power-off.
- Disable Noctalia idle auto-suspend for `aspen3`.
- Keep `aspen3` awake on external power or docked lid-close events, while leaving battery lid behavior to logind defaults.

## Impact

- **Files**: `inventory/home-profiles/brittonr/noctalia/idle.nix`, `machines/aspen3/configuration.nix`
- **Testing**: focused `aspen3` evaluation checks that `swayidle` no longer renders a `systemctl suspend` timeout for `aspen3`, a negative/contrast check that the shared default still renders suspend when enabled, and Cairn validation.
