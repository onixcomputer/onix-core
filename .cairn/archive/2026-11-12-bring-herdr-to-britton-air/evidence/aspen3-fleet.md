# aspen3 fleet deploy

Deployed 2026-11-11 from the working tree (the full pending dependency cohort,
not the `herdr-britton-air` review branch, which would omit deployed features
such as aspen3's `herdr-app` and `grok-bot`).

## Result

- Generation `system-110-link`
- System `/nix/store/b4hglwz317g81xfagzpayr41qhxif997-nixos-system-aspen3-26.11.20261106.4fe25e1`
- NixOS `26.11.20261106.4fe25e1 (Zokor)`

## Herdr preservation

- `herdr-iroh.service` hash `f15b228858a4ce231bc9e95e5ff2b5de813b53399df453ef8fa5480dcf5c90fe`
  — identical to the pre-switch unit.
- Relay endpoint `700c67336e748ea04824512dfd47df2050fa7ff8a07f8560d5e2359e1c1528dc`
  — unchanged.
- Main PID `667365`, active since 2026-11-11 04:12:19 EST — the switch did not
  restart the relay.
- `herdr 0.9.3`, 8 plugins, `herdr/config.toml` hash
  `3896e0418a91c1556717898b13e24ee20720b10b9de6eb3291130b1ad189e251`.
- `herdr-app` and `grok-bot` remain installed.

## First switch and fix

The first switch (system `b65s4z4r…`) left `home-manager-brittonr` failing:
the Darwin relay's `/Users/brittonr` state-dir activation ran on NixOS. The
`home-manager-profiles` loader imports every `.nix` file in a profile
directory, so removing the conditional `imports` line from `default.nix` did
not stop it. The relay module was moved to `machines/britton-air/darwin-relay.nix`;
the corrected system `b4hglwz3…` no longer contains `herdrIrohStateDirectory`
or `/Users/brittonr`, and Home Manager activation finished cleanly.

britton-air needs no rebuild: evaluating its toplevel after the move yields the
running system `/nix/store/jjygp79jpxr4dm7wlb9rr807islrippd-darwin-system-26.11.bb0b90d`.

britton-desktop was not switched; activation requires interactive sudo on this
host.
