## 1. Flake Input Deduplication

- [x] 1.1 Add `srvos` input: `github:nix-community/srvos` with `inputs.nixpkgs.follows = "nixpkgs"`
- [x] 1.2 Add `disko` as top-level input: `github:nix-community/disko` with `inputs.nixpkgs.follows = "nixpkgs"`
- [x] 1.3 Add `sops-nix` as top-level input: `github:Mic92/sops-nix` with `inputs.nixpkgs.follows = "nixpkgs"`
- [x] 1.4 Add `systems` as top-level input: `github:nix-systems/default`
- [x] 1.5 Thread `follows` into `clan-core`: add `disko`, `sops-nix`, `systems`, `nix-darwin` (if applicable)
- [x] 1.6 Thread `follows` into `buildbot-nix`: add `systems` if it accepts it (N/A — buildbot-nix has no systems input)
- [x] 1.7 Thread `follows` into `llm-agents`: verify `systems` follows is set (already has treefmt-nix, flake-parts)
- [x] 1.8 Audit all other inputs for missing `follows` on `nixpkgs`, `flake-parts`, `treefmt-nix` (fixed nixvim.systems)
- [x] 1.9 Add `?shallow=1` to `clan-core` git URL
- [x] 1.10 Add `?shallow=1` to `buildbot-nix` git URL (N/A — github: already uses archive API, no benefit from shallow)
- [x] 1.11 Add `nixConfig.extra-substituters` and `nixConfig.extra-trusted-public-keys` stub (commented out, ready for future cache)
- [x] 1.12 Run `nix flake update` and verify lock file shrinks (1135->1122 lines, 54->53 nodes)
- [x] 1.13 Run `nix flake metadata --json` and confirm no duplicate nixpkgs/disko/sops-nix/systems nodes (nixpkgs/disko/sops-nix: 1 each; systems: 5 remaining from transitive flake-utils deps)

## 2. srvos Server Hardening

- [x] 2.1 Import `inputs.srvos.nixosModules.common` in `inventory/tags/nixos.nix` (or common tag import)
- [x] 2.2 Import `inputs.srvos.nixosModules.mixins-nix-experimental` in `inventory/tags/nixos.nix`
- [x] 2.3 Import `inputs.srvos.nixosModules.mixins-trusted-nix-caches` in `inventory/tags/nixos.nix`
- [x] 2.4 Audit `inventory/tags/nixos.nix` for settings that srvos now covers — removed stopIfChanged for networkd/resolved (srvos covers these). Kept: nftables (srvos doesn't set), useNetworkd=false (we need NetworkManager), boot.tmp.useTmpfs (different from srvos cleanOnBoot)
- [x] 2.5 Remove `networking.nftables.enable` if srvos common sets it (srvos doesn't set it — kept ours)
- [x] 2.6 Remove or verify nix experimental-features settings don't conflict with srvos mixin (no explicit setting in our config — no conflict)
- [x] 2.7 Check if srvos sets `programs.nano.enable = false` or similar — match our preferences (srvos doesn't touch nano)
- [x] 2.8 Pass `inputs` through to tag files if not already available (added `inputs` to nixos.nix args — already available via specialArgs)

## 3. FHS Compatibility

- [x] 3.1 Create `inventory/tags/fhs-compat.nix` with `programs.nix-ld.enable`, `services.envfs.enable`
- [x] 3.2 Add base library list: acl, attr, bzip2, dbus, expat, fontconfig, freetype, fuse3, icu, libnotify, libsodium, libssh, libunwind, libusb1, libuuid, nspr, nss, stdenv.cc.cc, util-linux, zlib, zstd
- [x] 3.3 Add graphics-conditional libraries gated on `config.hardware.graphics.enable`
- [x] 3.4 Import `fhs-compat.nix` from `inventory/tags/desktop.nix`
- [x] 3.5 Import `fhs-compat.nix` from `inventory/tags/dev.nix`

## 4. Laptop Safety

- [x] 4.1 Add `suspend-on-low-power` block to `inventory/tags/laptop.nix` (already existed, refactored to use let-binding)
- [x] 4.2 Define `powerInPercent` as a `let` binding defaulting to 10
- [x] 4.3 Add udev rule using `${toString powerInPercent}` instead of hardcoded "10"

## 5. Renovate Auto-Update

- [x] 5.1 Create `renovate.json` at repo root with `$schema`, `dependencyDashboard: true`, `nix.enabled: true`

## 6. Validation

- [x] 6.1 Run `build` for every machine and confirm no evaluation errors (all 8 NixOS machines eval clean)
- [x] 6.2 Run `nix flake check` and confirm all checks pass
- [x] 6.3 Run `validate` (pre-commit) and confirm clean (statix + treefmt pass)
- [x] 6.4 Spot-check one machine's config for srvos settings (utm-vm: auto-allocate-uids, cgroups, fetch-closure, recursive-nix, ca-derivations, blake3-hashes all present)
- [x] 6.5 Spot-check one desktop machine for nix-ld and envfs in the system config (britton-desktop: both true)
- [x] 6.6 Spot-check one laptop machine for the low-battery udev rule (britton-fw: capacity=="10" + systemctl suspend confirmed)
