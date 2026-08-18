## Why

The managed Herdr profile binds the Pueue dashboard, but its Space rows do not render the dashboard's running-task metadata.

The plugin can publish a bounded active-task overview through Herdr `0.7.5`. Typed workstation configuration must place those values in the sidebar without taking ownership of plugin runtime state.

## What Changes

- Require Herdr `0.7.5` or newer for the managed Pueue integration.
- Add typed Space sidebar rows for Pueue status and two running-task values.
- Style the status and task rows in local configuration while keeping values plugin-owned.
- Extend the focused Nix check with positive token checks and a negative unsafe-token check.

## Impact

- **Nickel profile:** Add typed sidebar layout data.
- **Rendered Herdr TOML:** Add three custom Space token rows.
- **Home Manager:** Continue to render data only; it does not run or supervise the plugin.
- **Validation:** Check compatibility and the exact safe metadata tokens.

## Out of Scope

- Installing, linking, building, starting, or restarting the plugin.
- Running a background Pueue monitor from Home Manager.
- Persisting metadata or adding Pueue environments, paths, or raw output to configuration.
