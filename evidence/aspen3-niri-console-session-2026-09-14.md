# Aspen3 Niri console session correction

Date: 2026-09-14

## Cause

The pinned Niri launcher omitted `XDG_SESSION_ID` from its environment imports. The console launcher held session `10`, but the Niri service received no session ID. Libseat then selected SSH session `2`, which had no display seat.

Niri remained active as a process but reported no outputs. The kernel detected the internal panel and the external HDMI display.

## Correction

The local Niri source at `/home/brittonr/git/niri/resources/niri-session` now preserves the console variables. It exports the Wayland session type and clears the systemd session variables at logout.

`inventory/home-profiles/brittonr/noctalia/lib/niri-package.nix` applies the correction to the pinned package through a script-only layer. The underlying compositor remains `/nix/store/c759njmlwj0hpbc91mjrq9njik4qh4pp-niri-8b3df34/bin/niri`.

## Tests

`inventory/home-profiles/brittonr/noctalia/lib/niri-session-test.sh` passed with session IDs `c42` and `c99`. It also rejected a second launch with an active Niri service. The original launcher failed with `Niri session test: XDG_SESSION_ID is absent from the variable list.`

The corrected package and the `aspen3` system build passed. Cairn validation returned `valid: true` with no substance issues. The build compared against the deployed system before activation.

## Deployment

The previous system was `/nix/store/qkh610jnl74l9r2vc5hbs21gni3yny05-nixos-system-aspen3-26.11.20260913.02f5696`.

The active system and boot profile now point to `/nix/store/ynn8xvpdw17cln9q8413mbgcwb90pnga-nixos-system-aspen3-26.11.20260913.02f5696`. The total size increased by 9.93 KiB. The only changed system service definition was `home-manager-brittonr.service`.

Activation completed at 19:28 EDT and updated the GRUB menu. The installed launcher resolves to `/nix/store/x0cmdy5rb77i1pk57gw7iffq56xasap2-niri-8b3df34-console-session/bin/niri-session`.

## Runtime result

Niri restarted at 19:13 EDT with the correct console context. Its process ID remained `28555` after the later system activation. Console session `10` was active with type `wayland`.

The output check at 19:29 EDT reported both current modes:

- `eDP-1`: 2560 by 1600 at 180 Hz.
- `HDMI-A-1`: 3840 by 2160 at 59.997 Hz.

Noctalia, `iio-niri.service`, and `niri-sticky-daemon.service` were active. The recovery also restored `swayidle.service` after the compositor restart.

## Limits

No reboot test ran. A separate duplicate Polkit autostart unit retained its earlier failure, but the authentication agent process was active.

The source edits remain uncommitted. This task did not change the existing `flake.lock` edits.
