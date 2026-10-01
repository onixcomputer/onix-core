## Session identity

The launcher imports `XDG_SESSION_ID`, `XDG_SEAT`, and `XDG_VTNR` from the console login. It exports `XDG_SESSION_TYPE=wayland` before the systemd and D-Bus imports.

The launcher removes the console session variables from the systemd environment at logout. A later session must not inherit a stale session ID.

## Package correction

A symlink package preserves the existing Niri binary and its library compatibility override. Exact substitutions change only `bin/niri-session`. The build fails if the pinned launcher no longer matches the expected source.

## Tests

Mock commands test two different console session IDs. The tests require both imports before service start and context removal after service exit. A separate test rejects a second launch when Niri is active.

The original launcher is a negative fixture. Runtime evidence comes from `aspen3`, where the console session must be active and both display outputs must have current modes.

## Deployment boundary

The live recovery uses the active console session ID and restarts only Niri and its affected desktop services. A focused deployment must preserve the current system and unrelated package versions.
