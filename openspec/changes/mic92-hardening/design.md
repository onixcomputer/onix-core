## Context

The onix-core flake manages multiple NixOS machines via clan-core. Server hardening, nix daemon tuning, and firewall defaults are hand-rolled in `inventory/tags/nixos.nix`. The flake lock contains duplicate input trees because several downstream inputs (clan-core, buildbot-nix, llm-agents) bring their own copies of disko, sops-nix, systems, etc. Desktop machines cannot run unpatched binaries without manual `nix-shell` wrappers. Laptop machines have no protection against battery death.

Mic92's dotfiles (a comparable clan-core-based infrastructure) have solved each of these with well-tested, low-touch patterns. This design adopts seven of them.

## Goals / Non-Goals

**Goals:**
- Apply srvos baseline to all NixOS machines without regressing existing behavior
- Collapse duplicate input trees in the flake lock
- Let unpatched binaries run on desktop/dev machines
- Protect laptops from battery death
- Automate input freshness tracking via Renovate

**Non-Goals:**
- Standing up a binary cache (Harmonia) — infrastructure not ready yet; the `nixConfig.extra-substituters` stub is prep work only
- Hourly update-prefetch from CI — requires buildbot integration first
- TPM-bound SSH keys — hardware not universal across our fleet
- Switching bootloader to Limine — GRUB is working fine
- `system.etc.overlay` / `userborn` — too new, not battle-tested enough

## Decisions

### 1. srvos modules go in the `nixos` tag, not per-machine

**Choice:** Import srvos in `inventory/tags/nixos.nix` (or a dedicated file imported by that tag).

**Alternative considered:** Import per-machine in `machines/*/configuration.nix`. Rejected because every NixOS machine should get the baseline, and per-machine imports are easy to forget.

**Rationale:** The `nixos` tag is already our "every NixOS machine" catch-all. srvos uses `mkDefault` for most settings, so machine-specific overrides still work.

### 2. srvos modules selected: common + mixins-nix-experimental + mixins-trusted-nix-caches

**Choice:** Three modules. Skip `mixins-telegraf` (we use Prometheus, not Telegraf) and `mixins-systemd-boot` (we use GRUB).

**Alternative considered:** Import all mixins. Rejected because telegraf conflicts with our Prometheus stack and systemd-boot conflicts with GRUB.

### 3. Audit nixos.nix for srvos overlap before importing

**Choice:** After adding srvos, remove any settings from our `nixos.nix` that srvos already covers. Document each removal in the commit message.

**Rationale:** srvos sets things like `networking.nftables.enable`, nix experimental features, journal limits, etc. Leaving our copies creates `mkDefault` priority races.

### 4. disko and sops-nix promoted to top-level inputs

**Choice:** Declare `disko` and `sops-nix` as direct flake inputs, then `follows` them into clan-core.

**Alternative considered:** Leave them as transitive deps of clan-core. Rejected because we can't `follows` them into other inputs without a top-level declaration, and having them top-level lets us pin versions independently.

### 5. fhs-compat in a new tag file, applied via `desktop` and `dev` tags

**Choice:** Create `inventory/tags/fhs-compat.nix` and import it from both `desktop.nix` and `dev.nix`.

**Alternative considered:** Inline in `desktop.nix`. Rejected because dev servers also need it and a separate file keeps concerns clean.

**Library list:** Start with Mic92's curated list (acl, attr, bzip2, dbus, expat, fontconfig, freetype, fuse3, icu, libnotify, libsodium, libssh, libunwind, libusb1, libuuid, nspr, nss, stdenv.cc.cc, util-linux, zlib, zstd) plus the graphics-conditional set (pipewire, cups, mesa, libdrm, etc.) gated on `config.hardware.graphics.enable`.

### 6. suspend-on-low-power uses udev, threshold as a let-binding

**Choice:** Single udev rule in `inventory/tags/laptop.nix` with `powerInPercent` as a `let` binding (defaults to 10). Machines can override via `mkForce` if needed.

**Alternative considered:** A full NixOS option with `mkOption`. Overkill for a single integer that rarely changes.

### 7. Shallow clones only for git+https inputs

**Choice:** Add `?shallow=1` to `clan-core` and `buildbot-nix` URLs. Do not touch GitHub shorthand inputs (`github:owner/repo`) because those already use the GitHub archive API (no git clone).

**Rationale:** `?shallow=1` only matters for `git+https://` URLs where nix does a full `git clone` by default.

## Risks / Trade-offs

- **[srvos breakage]** srvos could set a default that conflicts with a machine-specific setting we haven't audited. → Mitigation: `build` every machine after the change before deploying. srvos uses `mkDefault` so any explicit setting wins.

- **[follows cascade]** Adding `follows` can break an input if the version of the followed dep is incompatible with what the input expects. → Mitigation: `nix flake check` after lock update. If an input breaks, drop that specific `follows` and file upstream.

- **[nix-ld library drift]** The curated library list will go stale as packages update. → Mitigation: The list is broad enough to cover common cases. Revisit when something breaks.

- **[renovate noise]** Renovate may create many PRs for inputs we don't want to update frequently. → Mitigation: Start with default schedule. Add `packageRules` later to batch or throttle noisy inputs.

## Migration Plan

1. **Branch:** Create feature branch `mic92-hardening`
2. **flake.nix changes:** Add srvos, disko, sops-nix, systems inputs. Thread follows. Add shallow=1. Add nixConfig stub.
3. **`nix flake update`** to regenerate lock
4. **Tag changes:** Add srvos imports to nixos tag. Audit and remove overlapping settings. Add fhs-compat.nix. Add suspend-on-low-power to laptop.nix.
5. **renovate.json:** Add to repo root.
6. **Validate:** `build` every machine. `nix flake check`.
7. **Deploy:** Roll out to one machine first (dev box), then cascade.
8. **Rollback:** Revert the branch. All changes are in nix config — no runtime state to clean up.

## Open Questions

- Should we include `srvos.nixosModules.mixins-mdns` for Avahi? We already enable Avahi in `nixos.nix` — check if srvos's version is equivalent.
- Do any of our inputs pin `home-manager` transitively? If so, add a `follows` for that too.
- Should `fhs-compat` be its own tag that machines opt into, or auto-applied via desktop/dev? Leaning toward auto-apply.
