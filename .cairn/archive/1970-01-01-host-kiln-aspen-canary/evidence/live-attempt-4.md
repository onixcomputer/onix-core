# Live attempt 4: uncertainty drill authority

Date: 2026-08-28

## Verdict

FAIL before provider substitution. PASS for unchanged long-lived services and socket restoration state.

## Observations

The accepted, exact replay, rejected, and unavailable drills passed on system closure:

`/nix/store/83rhhrw1zpwz7ipl08jk7937mhp4p0i2-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

The uncertainty unit failed while creating its first temporary receipt:

`mktemp: ... Permission denied`

The unit ran as root but had an empty capability set. It therefore had no DAC override for the mode-`0700` host-owned receipt directory. The drill did not rename or replace the Lattice socket. Both long-lived services remained active.

## Correction

Run the uncertainty unit as the Aspen host user and socket group.

That identity already owns the receipt directory and has the declared group authority to rename entries in the shared runtime directory. Remove `runuser` and the `util-linux` runtime dependency.

The corrected shell keeps no ambient root impersonation or extra capability.
