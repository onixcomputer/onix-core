## Why

Niri lost `XDG_SESSION_ID` between greetd and the user service on `aspen3`. Libseat selected an SSH session instead of the console session. Niri then reported no display outputs.

## What Changes

The launcher preserves the console session variables and sets the session type to Wayland. It clears those variables from systemd when the session ends.

A script-only package layer applies the correction to the pinned Niri package. The compositor binary stays unchanged.

## Impact

The correction applies to the shared Niri package in `inventory/home-profiles/brittonr/noctalia/lib/niri-package.nix`. It does not change the Niri input or the existing lockfile edits.
