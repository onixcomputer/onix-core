# Upstream Niri on Aspen3

## Package and session boundary

`flake.nix` follows `github:niri-wm/niri` at the `flake.lock` revision `ed22699d99462f61ab171472d3ea67e844ea580d`. Upstream's flake already builds with `libdisplay-info_0_3`; the local `niri-package.nix` override is obsolete. The shared Noctalia compositor, gesture handler, and sticky-window daemon all resolve the same upstream package. Aspen3's greetd command points directly at that package's `bin/niri-session`; the Home Manager `niri.service` still starts the existing wrapped binary, whose package is the same upstream input. Other hosts retain their profile-based greeter command but acquire upstream via the shared Home Manager profile.

## Configuration compatibility

Upstream rejects the fork-only `overview.workspace-gap`, `layout.focus-column-tile`, and `fit-workspace-columns` (including its grid option). Remove those settings, the two affected keybindings, the action registry entry, and the empty raw-binding group. Do not map grid fitting or spatial tile selection onto actions with different semantics. Keep the established mutable `config.kdl`, seeded `noctalia.kdl`, wrapper, service, and color-reload path. The host's generated config must validate with both the empty include used by the build and the seeded include used on first activation.

## Verification and rollout

The focused build check `checks.x86_64-linux.aspen3-input-palm-rejection` forces Niri config validation and verifies Aspen3's palm-safe touchpad settings. Direct `niri validate -c` runs covered the seeded Noctalia include and Aspen3's activated config. Greeter and service evaluations established the selected executable paths; the package build and `niri --version` exercised the real CLI.

With user authorization, Clan deployed the Aspen3 generation, including other pending workspace changes. `/run/current-system` is `/nix/store/7ifyraxyj86zjj8s52xrv9y27f9raimi-nixos-system-aspen3-26.11.20260929.b6c8664`; the live profile reports `niri 26.04 (ed22699)`. Greetd was restarted and its process now loads the new config with the pinned upstream `niri-session`. The stale fork-based user `niri.service` was stopped while greetd owned seat0; its new unit points to the upstream wrapper and will start on the next console login. No interactive graphical login was performed. Activation also reported failures in the unrelated `celld-site-storage-provision.service` and `celld.service` (connection refused at `100.108.13.4:39000`). Rollback is a previous generation or a deliberate revert of the upstream input and KDL cutover together, not a package-only pin rollback.
