# Deploy bounded RWKV-7 persistent decode observation

## Why

The admitted RWKV-7 P150x2 persistent decode runtime and fail-closed monitor are accepted in `tenstorrent.nix`, but `britton-desktop` does not install them. The host cannot run the required post-admission production observation through stable system paths.

## What changes

- Pin `onix-core` to the accepted `tenstorrent.nix` revision `53e3f321990810c80ad32ae9c8cd521863231bfc`.
- Re-export and install `rwkv7-p150x2-runtime` and `rwkv7-p150x2-evidence` on `britton-desktop`.
- Build and activate the exact system closure.
- Run one bounded physical observation for admitted windows `[2, 4]` with explicit telemetry receipt paths.
- Retain the aggregate fail-closed monitoring receipt and deployment evidence.

## Impact

The host gains operator commands and policies only. This change does not create a daemon, route live traffic, enable window `8`, or weaken any runtime interlock or monitoring rule.
