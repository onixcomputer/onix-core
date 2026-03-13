## Why

Our NixOS infrastructure lacks server hardening baselines, has duplicated input trees in the flake lock, and is missing several low-effort/high-value patterns that Mic92's production dotfiles have proven out. Adopting these closes gaps in security, eval performance, binary compatibility, and operational resilience.

## What Changes

- Add **srvos** as an input and apply `common`, `mixins-nix-experimental`, and `mixins-trusted-nix-caches` to all NixOS machines via the `nixos` tag. This replaces ad-hoc hardening we've accumulated.
- Thread **`follows`** through all flake inputs that depend on `disko`, `sops-nix`, `systems`, `nix-darwin`, `home-manager`, and `crane` to collapse the lock file.
- Add **`?shallow=1`** to heavy git inputs (`nixpkgs`, `clan-core`, `buildbot-nix`) to speed up `nix flake update`.
- Enable **`nix-ld` + `envfs`** on desktop/dev machines via a new tag so unpatched binaries (AppImages, vendored tools, downloaded CLIs) work without wrappers.
- Add a **`suspend-on-low-power`** udev rule to laptop machines — auto-suspend at 10% battery.
- Add **`renovate.json`** to the repo for automated flake input update PRs.
- Expose a **`nixConfig.extra-substituters`** block in `flake.nix` if/when we stand up a binary cache, structured so it's a one-line enable.

## Capabilities

### New Capabilities
- `srvos-hardening`: Import srvos server hardening modules into the base NixOS tag. Covers SSH hardening, nix daemon settings, systemd journal limits, trusted caches, and experimental features.
- `fhs-compat`: Enable nix-ld and envfs on desktop/dev machines. Provides a curated library set for common unpatched binaries (graphics, audio, crypto, USB).
- `input-dedup`: Aggressive `follows` across all flake inputs and `?shallow=1` on heavy git sources. Reduces lock file size and eval/fetch time.
- `laptop-safety`: Udev rule to auto-suspend on low battery. Applies to machines with the `laptop` tag.
- `renovate-auto-update`: Add renovate.json config for automated flake input freshness PRs.

### Modified Capabilities
<!-- No existing specs to modify — first specs in the project. -->

## Impact

- **`flake.nix`**: New `srvos` input, `follows` additions on ~10 existing inputs, `?shallow=1` on 3 inputs, `nixConfig.extra-substituters` stub.
- **`flake.lock`**: Significantly smaller after dedup. Will change hashes for every input that gains a `follows`.
- **`inventory/tags/nixos.nix`**: Import srvos modules, remove settings that srvos now covers (to avoid conflicts).
- **`inventory/tags/desktop.nix`** or new `inventory/tags/fhs-compat.nix`**: nix-ld + envfs config.
- **`inventory/tags/laptop.nix`**: suspend-on-low-power udev rule.
- **`renovate.json`**: New file at repo root.
- **All machines**: Will see srvos defaults applied on next deploy. Non-breaking — srvos uses `mkDefault` extensively.
