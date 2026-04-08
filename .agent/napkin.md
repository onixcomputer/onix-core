# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-03-22 | self | `nix.gc.dates = "daily"` in guest tag conflicts with nix-gc service module's `"weekly"` — both target nixos machines | Use `lib.mkForce` on tag-specific GC settings that intentionally override service-level defaults |
| 2026-03-22 | self | `nix eval` of britton-desktop's ExecStart fails with `dynamic-derivations` error when referencing `kernel.dev` output | Use `nix build` instead of `nix eval` for attributes that reference multi-output derivation paths — build resolves them, eval may not |
| 2026-03-22 | self | `networking.interfaces.${tapInterface}` in NixOS only runs once at boot — doesn't re-apply when a TAP interface is deleted and recreated by ExecStopPost/ExecStartPre | Assign IP directly in ExecStartPre with `ip addr add`, don't rely on networking.interfaces for dynamically-created interfaces |
| 2026-03-22 | self | cloud-hypervisor autodetects raw disk images and disables sector 0 writes (`Autodetected raw image type. Disabling sector 0 writes.`) — ext4 superblock at offset 1024 falls within sector 0, breaking remount-fs | Use GPT partition table so ext4 starts past sector 0. The partition starts at sector 2048 (1MB offset), keeping the superblock safe |
| 2026-03-22 | self | `nixos-install` creates symlinks `/etc/systemd/network/X → /etc/static/systemd/network/X` but `/etc/static` → nix store path. Running host-side `activate` creates store paths not in guest's closure | Never run activation from host chroot. Let `nixos-install` handle it — it copies the closure and sets up the profile. Guest's init/activation runs on first boot |
| 2026-03-22 | self | cloud-hypervisor guest VM sends zero packets on TAP interface despite booting to multi-user with all services green | ROOT CAUSE: `/etc/machine-id` missing. systemd-networkd's DHCPv4 client needs machine-id for DUID generation → fails with ENOENT. `nixos-install` in chroot can't create machine-id when `/etc/` is read-only nix store overlay (system.etc.overlay.enable from srvos). Fix: generate machine-id in bootstrap.sh after nixos-install. Also hardened: Driver=virtio_net match, ConfigureWithoutCarrier, ActivationPolicy=up, delete+recreate TAP, dnsmasq SIGHUP. |
| 2026-03-22 | self | `clan vars generate` needs a TTY for password prompts — can't run from pueue or non-interactive shell | Run `clan vars generate <machine>` interactively in a terminal before building machines that need vars |
| 2026-03-13 | self | New files in `inventory/tags/` not found by nix eval — "path does not exist" in store | Must `git add` new files before nix can see them (nix copies flake source from git index, not working tree) |
| 2026-03-13 | self | srvos `security.sudo.execWheelOnly = true` conflicts with per-user `sudo.extraRules` on britton-desktop | Need `lib.mkForce false` to override srvos's non-mkDefault setting. Also needed to add `lib` to module args. |
| 2026-03-13 | self | statix rejects repeated attrset keys (`inputs.X.follows` style on separate lines, multiple `security` blocks) | Use nested attrset `inputs = { ... }` form and merge all `security.*` into a single `security = { ... }` block |
| 2026-03-13 | self | statix also rejects `roles.server.X = ...; roles.client.Y = ...;` and `files.a = {}; files.b = {};` — same repeated key issue | Always use nested form: `roles = { server = ...; client = ...; };` and `files = { a = {}; b = {}; };` |
| 2026-03-13 | self | Vars generator `dependencies` field doesn't make dependent var's runtime path available in the script | Combine related secrets into a single generator instead of cross-referencing between generators |
| 2026-03-13 | self | Harmonia is pull-based (serves from local nix store), can't `nix copy --to` it | To populate a remote nix cache, use `nix copy --to ssh://host` or niks3, not harmonia's HTTP endpoint |
| 2026-03-11 | user | `system.etc.overlay.enable = true` without `services.userborn.enable = true` broke passwd database — user disappeared from `/etc/passwd`, `sudo: you do not exist` | Overlayfs `/etc` REQUIRES userborn. Never enable overlay without also enabling `services.userborn.enable = true`. Or just don't use overlay `/etc` — the benefit is marginal. |
| 2026-03-12 | self | Created `niri-keybinds.nix` as a plain function `{ config, pkgs, lib }:` directly in the `noctalia/` profile directory. Clan-core auto-imports all `.nix` files in a profile dir as modules, so it tried to pass module args (`inputs` etc.) to the function → crash. | Plain Nix data/function files that aren't modules must go in a subdirectory (e.g., `lib/` or `noctalia-sections/`) to avoid auto-import. Only put actual NixOS/HM modules directly in profile directories. |

| 2026-03-13 | self | `import ../inventory/core/machines.nix { }` returns `{ machines = { ... }; }`, not the machines attrset directly | Use `(import ../inventory/core/machines.nix { }).machines` to get the machine names |
| 2026-03-13 | self | `inputs'` in adios-flake doesn't give access to `legacyPackages` on clan-core — use `self.inputs.clan-core.legacyPackages.${system}` instead | adios-flake `inputs'` maps to perSystem outputs (packages, etc.). For legacyPackages access, go through `self.inputs.<input>.legacyPackages.${system}` |
| 2026-03-13 | self | adios-flake wrapper modules with `@args` pattern get formal args stripped by nixfmt → adios can't detect system dependency → passes wrong arg set | Never use `@args` pass-through with adios-flake. Explicitly destructure ALL needed args AND reference them in the body (e.g. via `inherit`). nixfmt strips unused destructured bindings. |
| 2026-03-13 | self | adios-flake `flake` parameter handles non-standard outputs (clan, clanInternals) that modules can't — only `defaultFlakeOutputs` (nixosConfigurations, lib, etc.) work from modules | Use `flake = import ./file.nix { ... }` for clan outputs. Use modules only for per-system outputs (checks, packages, devShells, formatter). |
| 2026-03-13 | self | `time.timeZone = null` in a tag conflicts with hardcoded `time.timeZone = "America/New_York"` in machine configs | Remove hardcoded timezone from machines that get the tag with `automatic-timezoned` |
| 2026-03-16 | self | nix-wasm fork's flake pin brought old nixpkgs (rustc 1.86), wasmtime 40.0.2 needs 1.89+ | Always add `inputs.nixpkgs.follows = "nixpkgs"` when importing flakes with heavy native builds |
| 2026-03-16 | self | Cherry-picked PR compiled textually but API differences caused 6 C++ errors (`realisePath` as method vs free function, `.impl` vs `.fun`, brace-init issues) | Cherry-picks across API boundaries need compile testing, not just clean git apply |
| 2026-03-16 | self | nix fork's lowdown 2.0.2 override kept 2.0.4 patches from followed nixpkgs → build failure | When overriding `.src` version in `overrideAttrs`, also clear `patches = []` if the patches are version-specific |
| 2026-03-16 | self | nix flake's `packages.*.nix` includes functional tests as `checkInputs` → stale-file-handle overlayfs test fails in sandbox | Use `.overrideAttrs (_: { doCheck = false; })` to skip upstream tests in fork packages |
| 2026-03-16 | self | SSH `%t` token in `IdentityAgent` path unsupported by OpenSSH 10.2 | Use `${XDG_RUNTIME_DIR}` env var expansion (supported per ssh_config ENVIRONMENT VARIABLES section), NOT hardcoded `/run/user/<uid>`. The HM module already generates the correct syntax. |
| 2026-03-16 | self | wasm-opt rejects Rust wasm32-unknown-unknown output: `memory.copy operations require bulk memory operations` | Rust's wasm32 target emits bulk-memory ops by default. Pass `--enable-bulk-memory` to wasm-opt. |
| 2026-03-16 | self | Nix fork binary inside sandbox check fails: `experimental Nix feature 'nix-command' is disabled` and `creating directory '/nix/var/nix/profiles': Permission denied` | In sandbox checks, use `--store dummy:// --offline --extra-experimental-features 'nix-command flakes wasm-builtin'` and `export HOME=$TMPDIR` |
| 2026-03-16 | self | CARGO_TARGET_DIR env var set to `~/.cargo-target` — cargo build output not in `./target/` | Check `$CARGO_TARGET_DIR` when looking for build artifacts; don't assume `./target/` |
| 2026-03-16 | self | SSH `HostName` resolution causes host key check against resolved name, not the `Host` alias. System known_hosts has `iroh-aspen2` but SSH checks for `aspen2` (the `HostName`). User SSH works because `~/.ssh/known_hosts` has `aspen2`; nix daemon (root) fails because `/etc/ssh/ssh_known_hosts` only has `iroh-aspen2` | Add `HostkeyAlias iroh-<machine>` to ProxyCommand SSH configs so host key verification uses the alias name that matches known_hosts entries |
| 2026-03-16 | self | `nix_wasm_init_v1` defined in both `nix-wasm-rust` crate AND plugin crate → `symbol multiply defined` linker error with LTO | Don't redefine `nix_wasm_init_v1` in plugin crates — it's already exported by the `nix-wasm-rust` dependency |
| 2026-03-16 | self | Nickel's malachite (big numbers) emits `trunc_sat` WASM instructions that wasm-opt rejects with `--enable-bulk-memory` alone | Add `--enable-nontrapping-float-to-int` to wasm-opt flags for crates using malachite/nickel |
| 2026-03-16 | self | Nickel's `CacheHub::resolve` calls `std::env::current_dir()` and `std::fs::read_to_string()` during import resolution — both fail on wasm32-unknown-unknown | Vendor nickel-lang-core, add `SourceIO` trait to abstract the 3 callsites in `cache.rs`, inject `WasmHostIO` that routes through nix-wasm `read_file`/`make_path`. Also need `Arc<dyn SourceIO>` (not Box) because SourceCache derives Clone. |
| 2026-03-16 | self | Nickel upstream uses edition 2024 (let chains) but workspace Cargo.tomls say edition.workspace = true | When vendoring, resolve workspace edition to "2024" in all three crate Cargo.tomls |
| 2026-03-16 | self | Nickel `Error` and `PointedExportErrorData` don't implement `Display` — `format!("{e}")` fails | Use `{e:?}` (Debug) format for Nickel error types in WASM plugin panic messages |

| 2026-03-25 | self | `qt.platformTheme.name = "gtk"` sets `QT_QPA_PLATFORMTHEME=gtk2`, loading GTK2's X11 backend (`libgdk-x11-2.0.so.0`) into quickshell. On suspend/resume, X11 connection goes stale → `gdk_x_io_error` → `exit()` → Qt render thread SIGSEGV during cleanup. 6 crashes/week. | Use `platformTheme.name = "adwaita"` — pure Qt, no GTK2/X11 dependency. Wayland-native apps must never load GTK2. |
| 2026-03-25 | self | Wezterm removed `--config` CLI flag — `wezterm start --config 'key = value'` no longer works | Use kitty with `-o key=value` for inline config overrides, or write a dedicated wezterm lua config file referenced via `WEZTERM_CONFIG_FILE` env var |

## User Preferences
- Prefers deleting dead code over commenting it out
- When cleanup items overlap (e.g., opentofu lib + cloud/ + parts/checks.nix + parts/vm-checks.nix + cloud devShell all reference each other), chase all the references down in one pass

## Domain Notes (continued)
- **Screenshot flakiness on niri**: Two causes. (1) `grim` uses `zwlr_screencopy` which synchronously blocks niri's compositor thread for ~45ms on NVIDIA 3840x2160@240Hz (~10 dropped frames = visible freeze). niri's built-in `screenshot-screen` action is faster (~27ms) since it skips the Wayland client round-trip. (2) `screenshot-region`'s `flock -n` held the lock for satty's entire lifetime, so re-triggering right after closing satty silently exited. Fixed by replacing flock with `pkill -x satty`.
- britton-desktop: NVIDIA RTX (PCI 10DE:2C02) card2 DP-3 3840x2160@240Hz, AMD iGPU (1002:13C0) card1. NVIDIA driver 580.126.18 open kernel module.
- ~~lisgd-niri service crash-loops continuously on britton-desktop~~ — RESOLVED. Script checks for touchscreen via libinput, exits 0 if none found. `Restart = "on-failure"` won't restart on exit 0. `StartLimitBurst = 3` caps restarts if lisgd itself crashes on a machine with a touchscreen.

## Reference Repos
- **Mic92/dotfiles**: Clan-core infra, srvos, ZFS-first, borgbackup w/ ZFS snapshots, sops-nix, zerotier+wireguard mesh, promtail→loki, buildbot CI, limine secure boot via clan vars, update-prefetch (hourly background pull of next system), nix-index-database/comma, treefmt-nix comprehensive formatter, FHS compat (envfs + nix-ld), iroh-ssh module, TPM-based SSH agent, keyd, data-mesher
- **clan/clan-infra**: Official clan.lol infra. _class-aware admins.nix (darwin+nixos), signing.nix (auto-discover per-machine nix keys), initrd-networking.nix, vars+secrets flake checks, machinesPerSystem build checks, SSH key auto-propagation to root, buildbot-nix CI

## Domain Notes (dbus-broker)
- **dbus-broker + NixOS symlink atomicity**: dbus-broker-launch monitors service file directories via inotify. When NixOS switches generations and atomically replaces `/run/current-system` symlink, the inotify watches on old store paths go stale. dbus-broker never discovers new D-Bus services (like `ca.desrt.dconf`) added in the new generation. Fix: SIGHUP `dbus-broker-launch` to force config reload before home-manager activation. Implemented in `inventory/tags/desktop.nix`.
- The `hm-setup-env` script imports `DBUS_SESSION_BUS_ADDRESS` from the user's systemd session if logged in. When set, the activation script uses the user's session bus directly (skipping dbus-run-session fallback), making it dependent on the user's dbus-broker having up-to-date service catalogs.

## Domain Notes (DisplayLink/evdi + NVIDIA)
- Elgato Prompter (17e9:ff1a) is a DisplayLink device using evdi kernel driver. Connector: DVI-I-1, mode: 1024x600@60.
- evdi creates a DRM card (card0) with NO render node (no renderD*). Niri falls back to the primary GPU's render node for buffer allocation.
- NVIDIA's GBM allocator doesn't export linear dmabufs in formats evdi accepts (XRGB8888 etc.) → NoSupportedRendererFormat.
- Fix: `debug { render-drm-device "/dev/dri/renderD128" }` in niri config → AMD iGPU renders for evdi. NVIDIA outputs still use their own renderD129.
- GBM_BACKEND=nvidia-drm env var is fine — NVIDIA's GBM wrapper forwards non-NVIDIA device calls to mesa.
- PR #2891 fixed DisplayLink for Asahi (open driver), not NVIDIA proprietary.

## Domain Notes (Noctalia ↔ Niri theme sync)
- Noctalia stores runtime config in `~/.config/noctalia/` — `colors.json` (M3 palette), `settings.json` (all settings). HM module writes both as nix-store symlinks via `xdg.configFile`.
- Noctalia has a built-in template system: `Assets/Templates/niri.kdl` generates `~/.config/niri/noctalia.kdl` with M3 colours. Post-hook (`template-apply.sh niri`) adds `include "./noctalia.kdl"` to config.kdl.
- Template variables use `{{colors.primary.default.hex}}` syntax. Modes: dark/light/default. Formats: hex, hex_stripped, rgb, rgba, hsl, etc. Filters: `| set_alpha 0.5`, `| lighten 0.2`.
- Niri merges duplicate blocks (later values override earlier). So `include` at the end of config.kdl safely overrides just the colour properties in the layout block without clobbering gaps/widths/presets.
- Niri watches config.kdl for changes and auto-reloads, but does NOT watch included files. Need `niri msg action load-config-file` or a systemd path watcher on noctalia.kdl.
- `colors.json` MUST be writable for Noctalia's template processor (writes generated colours). Use `xdg.configFile.force = true` + activation script to convert symlink to real file.
- `settings.json` MUST also be writable. Noctalia's Settings singleton persists all UI changes (color scheme selection, dark mode toggle, scheduling mode, etc.) to `settings.json` via a `FileView` with `watchChanges: true`. Read-only symlink causes silent write failures, and the `watchChanges` listener can reload the stale store file mid-flight, reverting in-memory state. Both files use the same activation pattern: `force = true` + symlink-to-file conversion.
- Wrappers lib `types.file` supports `path = "$HOME/.config/niri/config.kdl"` — env vars expand at runtime in the wrapper's bash script.
- Noctalia IPC: `noctalia-shell ipc call colorScheme set <name>`, `darkMode toggle/setDark/setLight`. Full list via `noctalia-shell ipc show`.

## Domain Notes (upstream clan-core migration — COMPLETED)
- Switched from `adeci/clan-core` fork to upstream `clan/clan-core` main (March 2026).
- Roster module deleted. User management decomposed: upstream `users` for passwords/groups, local `all.nix` for UID/shell/SSH keys, `home-manager-profiles` clan service for HM.
- Upstream sshd module now ALWAYS generates openssh-ca shared var (no mkIf on searchDomains). Had to manually generate `vars/shared/openssh-ca/` keypair.
- Upstream removed `exportsModule` — replaced by `exportInterfaces`/`exports` system. Our `exports-module.nix` deleted; monitoring modules' `exports.serviceEndpoints` discovery needs rework.
- Upstream removed `facter.detected.graphics.amd.enable` — nixos-facter-modules integration changed. Removed the mkForce override.
- Upstream doesn't have `home-manager` as a direct flake input anymore. HM module imported via our top-level `inputs.home-manager`.
- Password vars renamed: `brittonr-password-hash` → `user-password-hash`, `brittonr-password` → `user-password`.
- Home-manager profiles assigned via tags: `hm-server` (base+dev), `hm-laptop` (base+dev+noctalia+social), direct machine ref for desktop (base+dev+noctalia+creative+social).
- Bonsai's monitor sharedModules moved from roster config to `machines/bonsai/configuration.nix`.
- Upstream auto-computes `all`, `nixos`, `darwin` tags. The `all` tag includes EVERY machine (including darwin). `all.nix` renamed to `nixos.nix` to use the NixOS-only computed tag. Services switched from `tags.all` to `tags.nixos`.
- The explicit `"all"` in each machine's tag list is now redundant (upstream auto-computes it). Removed from machines.nix.

## Domain Notes (iroh-ssh)
- iroh-ssh uses ed25519 keypairs for persistent node identity. Keys stored as z32-encoded strings in `~/.ssh/irohssh_ed25519{,.pub}`.
- The endpoint ID (used in `iroh-ssh proxy <id>` and `iroh-ssh user@<id>`) is the hex-encoded raw ed25519 public key (64 chars).
- The z32-encoded public key and the hex endpoint ID are different representations of the same key. Both stored in clan vars; hex `node-id` is what SSH ProxyCommand uses.
- `DynamicUser=true` requires explicit `HOME=/var/lib/iroh-ssh` and `ExecStartPre` to copy vars-managed keys into `$HOME/.ssh/`.
- iroh-ssh handles its own UDP port allocation for QUIC — no need to open wide UDP port ranges in the firewall.
- SSH Host entries use `iroh-<machine>` naming (e.g., `iroh-pine`) to coexist with regular hostname-based SSH entries. This lets you choose iroh vs direct path per-connection.
- The old module had no vars generator — keys were generated at first run and lived only in `/var/lib/iroh-ssh-*/`. No way to know endpoint IDs without SSHing to the machine first (chicken-and-egg).
- Pine's deploy changed from `pine.bison-tailor.ts.net` (Tailscale MagicDNS) to `iroh-pine` (iroh-ssh proxy). First machine fully off Tailscale for SSH deploy.

## Domain Notes (iroh-ssh deploy migration)
- All NixOS deploy targets now use `iroh-<machine>` except britton-desktop (local) and utm-vm.
- britton-air uses `britton-air.local` (mDNS via Avahi nssmdns4).
- Avahi reverse-resolved britton-air as `britton-air.localdomain` (not `.local`). Forward mDNS lookup timed out while Mac was sleeping — macOS sleep responds to ICMP but not mDNS/TCP. Works when awake.
- Machines currently offline (can't deploy): britton-gpd (56d), bonsai (4d), aspen2 (not in Tailscale, DNS unresolvable). These still have iroh-ssh vars generated; they'll get the service on next deploy.
- aspen1 has pre-existing failures: radicle-node (crash-loop), tailscaled-autoconnect (timeout — Tailscale offline 48d). Unrelated to iroh-ssh.
- Pine (PineNote) is completely offline — not reachable via iroh, Tailscale, or DNS. Deploy target is `iroh-pine` from a previous session.

## Domain Notes (buildbot migration to aspen2)
- Buildbot master moved from aspen1 to aspen2 (co-located with harmonia binary cache).
- `clan vars fix` and `clan vars generate` deadlock when shared vars don't exist yet — fix needs existing file, generate needs fix to pass health check. Break the cycle by creating the sops-encrypted file manually.
- Manually-created clan vars MUST use symlinks for `machines/<name>` and `users/<name>` entries (pointing to `../../../../../../sops/machines/<name>` etc.). Plain files/directories cause clan to compute wrong recipient sets.
- `clan vars fix` determines required sops recipients from: machine's own key + all keys in `groups/<groupname>` symlink targets + `users/<username>` symlink targets. If `machines/aspen2` is a plain file instead of a symlink to `sops/machines/aspen2`, clan can't resolve aspen2's age key → strips it from recipients → sops-install-secrets fails on the target.
- The `admins` sops group (`sops/groups/admins/`) can include other machines — e.g., aspen1 is in admins, so ALL secrets with `groups/admins` get aspen1's key as a recipient regardless of which machine the secret belongs to.
- buildbot-nix master module auto-creates nginx `/nix-outputs/` location with `autoindex on` when `outputsPath` is set. Don't add a duplicate location block.
- Cloudflare tunnel can proxy to remote hosts: `"buildbot.blr.dev" = "http://aspen2:80"` in aspen1's ingress forwards to aspen2.

## Domain Notes (Nix string escaping for shell XDG vars)
- `''${XDG_CONFIG_HOME:-$HOME/.config}` in `''...''` strings produces literal `${XDG_CONFIG_HOME:-$HOME/.config}` in bash output
- `\${XDG_CONFIG_HOME:-$HOME/.config}` in `"..."` strings produces the same literal `${...}` in output
- Writing bare `${XDG_CONFIG_HOME:-...}` in a `''...''` string triggers Nix interpolation — nixfmt silently "fixes" it to `${"XDG_CONFIG_HOME:-..."}` (Nix string literal interpolation) which drops the `${...}` shell wrapper from the output
- Always verify generated shell scripts with `nix eval --raw .#nixosConfigurations.<machine>.config.home-manager.users.<user>.home.activation.<name>.data`
- SSH config uses `%t` for `$XDG_RUNTIME_DIR` (same specifier as systemd)
- Fish uses `$__fish_config_dir` for its own config directory (respects `XDG_CONFIG_HOME`)

## Domain Notes (update-prefetch self-kill)
- `update-prefetch` calling `switch-to-configuration switch` directly is lethal: the switch stops `update-prefetch.service` (because it changed), killing the process running the switch. Result: switch never completes, retries every hour, each time killing itself.
- Fix: `systemd-run --unit=nixos-upgrade-switch --service-type=exec` launches the switch in a transient unit that survives the service stop.
- Also guard against the transient unit already running (`systemctl is-active nixos-upgrade-switch.service`).
- Buildbot-nix upstream sets NO `Restart` or `TimeoutStopSec` on the master service. Default `Restart=no` means any crash or failed stop leaves CI dead until manual intervention. Default 90s `TimeoutStopSec` is too short for graceful shutdown when many builds are in flight (16 workers × active builds = lots of cancel+cleanup). Fixed with `Restart=on-failure` + `TimeoutStopSec=300` in our clan module.

## Domain Notes (drift + clankers integration)
- **clankers unit2nix IFD broken**: clankers Cargo.toml has `path = "../subwayrat/crates/rat-*"` path deps to a sibling repo. unit2nix's `buildFromUnitGraphAuto` can't resolve these in sandbox. Created local `pkgs/clankers/default.nix` using `rustPlatform.buildRustPackage` that assembles both repos via `fetchFromGitHub` + `postUnpack`.
- **openspec has no git remote**: The `openspec = { path = "../openspec", optional = true }` dep has no remote — local-only repo. Solved by building with `--no-default-features --features tui-validate,zellij-share` to skip it.
- **clankers needs nightly Rust**: Added `rust-overlay` as a top-level flake input with `follows` from drift and clankers to deduplicate. Nightly toolchain constructed per-use site (`import nixpkgs { overlays = [(import inputs.rust-overlay)]; }`).
- **adios-flake `inputs'` doesn't resolve plain flakes**: `inputs'.drift.packages.default` fails because drift uses `forAllSystems` (not adios-flake/flake-parts). Use `self.inputs.drift.packages.${pkgs.system}.default` instead.
- **media HM profile had pre-existing bugs**: `lutris.nix` had `runners.*.enable` options that don't exist in the HM lutris module. `mpv.nix` bindings conflicted with `shared/desktop/media-viewers.nix`. Fixed with `lib.mkForce` on mpv and removing invalid lutris runner enables.
- **drift config.toml**: Managed declaratively via `xdg.configFile` in `inventory/home-profiles/brittonr/media/drift-config.nix`. References `mpdConfig` and `mediaPaths` options from base profile.
- **clankers clan service module**: Two roles: `daemon` (persistent agent sessions over iroh QUIC) and `router` (multi-provider LLM proxy). Daemon deployed to all `dev`-tagged machines, router to britton-desktop only.

## Domain Notes (Nickel WASM evalNickelFileWith)
- **Re-entrancy bug**: `evalNickelFileWith` calls `nix_to_nickel_source()` which recursively walks the args attrset via host ABI (`copy_attrset`, `get_attr`). If any arg is a lazy Nix thunk that triggers another WASM eval (e.g. `config.theme.data` wraps `wasm.evalNickelFile`), re-entrant WASM execution → crash (`Bindings::operator[]` assertion). Fixed in `lib/wasm.nix` with `forceDeep` — a recursive `mapAttrs`/`map` that rebuilds the value tree in normal Nix eval before entering WASM.
- **WASM stack limit**: even with forceDeep, large data (~500 fields, 4-5 nesting levels) overflows the WASM stack when `nix_to_nickel_source` serializes it to Nickel source text and Nickel parses it back. For large args (full theme data), flatten to simple strings in the Nix stub. For small args (sysctl params, builder targets, bat colors), forceDeep handles it transparently.
- **Approaches that don't work**: `builtins.deepSeq` — NixOS `config.*` has cycles → `max-call-depth exceeded`. `builtins.fromJSON(builtins.toJSON args)` — `toJSON` can't serialize Nix store paths (e.g. `gtk.theme.package`).
- **Flattening patterns**: extract `.hex` values in Nix (`c.bg.hex`), or bulk-flatten sub-records via `builtins.mapAttrs (_: v: v.hex) c.zen.dark`.
- **Nickel gotchas**: `fun { bg, .. } =>` destructuring causes `InfiniteRecursion` when field names match nested keys. Use `fun args =>` with `let` bindings. Don't name bindings `c` if the output has a `c` field (e.g. starship C language module shadows it).

## Domain Notes (clankers upstream NixOS modules)
- Upstream clankers flake now exports `nixosModules.clankers-daemon` and `nixosModules.clanker-router` with proper NixOS options (`services.clankers-daemon.*`, `services.clanker-router.*`).
- The router is a separate binary (`clanker-router serve`) from the `clanker-router` repo, not a subcommand of `clankers`. Built with `features = "cli"`.
- `inputs.clankers.packages.${system}.clanker-router` works (standalone repo, no path dep issues). `inputs.clankers.packages.${system}.clankers` fails (unit2nix IFD can't resolve `../subwayrat/` path deps in sandbox).
- Hybrid approach: import upstream NixOS modules for service definitions, use upstream package for the router, keep local `pkgs/clankers/default.nix` build for the daemon binary.
- Upstream modules create system users (`clankers`, `clanker-router`) with dedicated state dirs (`/var/lib/clankers`, `/var/lib/clanker-router`). API keys via `environmentFile`.
- Nix is lazy: accessing `inputs.clankers.packages.${system}.clanker-router` only evaluates `routerBuild`, not the broken `ws` workspace build.

## Domain Notes (clankers clan service — deployed)
- Upstream clankers flake at rev 5a767f6 has NixOS module that passes `--model` as CLI flag, but the binary doesn't accept it (`unexpected argument '--model'`). Fixed at rev 37e48a9 — model set via `CLANKERS_MODEL` env var.
- Updated flake input to 37e48a9 for the NixOS module fix. Kept local package build (`pkgs/clankers/`) at old source rev (5a767f6) because the new source added `ort-sys` dep that downloads prebuilt binaries during build (fails in nix sandbox).
- The old binary is compatible with the new module — `--heartbeat` and `--allow-all` work fine; `--model` was never a real CLI flag.
- `clanLib.selectExports`, `clanLib.parseScope`, `mkExports` — none of these exist in current clan-core. The original module used them speculatively. Replaced with direct settings (`apiBase`) and `config.services.clanker-router.enable or false` for colocation detection.
- Router mDNS warning is cosmetic: `Failed to create an address lookup service` — the sandboxed systemd service can't do mDNS, but iroh relay works.
- Daemon heartbeat warning: `iroh endpoint unavailable: Failed to create an address lookup service` — same mDNS issue. Heartbeat uses iroh for peer discovery; falls back gracefully.

## Domain Notes (Lemonade LLM server)
- Lemonade v10.0.1 builds from source with cmake+ninja in ~35s on the desktop. All deps available in nixpkgs except cpp-httplib (pkg-config name mismatch). Solved with FETCHCONTENT_SOURCE_DIR_HTTPLIB pointing to pre-fetched v0.26.0 source.
- The cmake target for the daemon binary is `lemonade-router` (not `lemond` despite `set(EXECUTABLE_NAME "lemond")` in CMakeLists.txt). The build output name changed at some point.
- Lemonade downloads pre-built llama-server binaries at first run (Ubuntu-linked, won't work on NixOS). Override via config.json `llamacpp.rocm_bin` pointing to llamacpp-rocm-rpc's `llama-server`.
- Config file lives at `$LEMONADE_CACHE_DIR/config.json` (or `$HOME/.cache/lemonade/config.json`). Loaded via `ConfigFile::load()`, merged over `defaults.json`. Env vars also work: `LEMONADE_LLAMACPP_ROCM_BIN`, `LEMONADE_HOST`, `LEMONADE_PORT`, etc.
- Resources (defaults.json, server_models.json, backend_versions.json) are resolved via `get_executable_dir()/resources` then fallback paths (`/usr/share/lemonade-server`, etc.). Symlink from `$out/bin/resources` to `$out/share/lemonade-server/resources` handles this.
- nix cmake hook: installPhase CWD is unpredictable (source root or build dir). Using `find /build` to locate binaries is reliable.
- OpenAI-compatible API at port 13305 by default. Also exposes Ollama-compatible and Anthropic-compatible API endpoints.
- gfx1151 (Strix Halo) is explicitly supported in Lemonade's ROCm config table.

| 2026-04-06 | self | Lemonade service passed `/var/lib/lemonade` as a positional arg to `lemonade-router`, causing `The following argument was not expected: /var/lib/lemonade` and a stuck deploy because `lemonade-model-pull` is a restart-on-failure oneshot waiting on the server | `lemonade-router` reads config from `LEMONADE_CACHE_DIR`/`config.json`; don't pass the state dir on `ExecStart`. Use only supported flags like `--host`/`--port`. |
| 2026-04-06 | self | `lemonade pull` defaults to `127.0.0.1:8000`, so the activation-time model pull silently talks to the wrong endpoint when the server is configured on another port (here `13305`) or bound to `0.0.0.0` | In activation scripts, pass `lemonade --host <local-connect-host> --port <configured-port> ...` explicitly. For servers bound to `0.0.0.0`/`::`, connect via `127.0.0.1`/`::1`, not the wildcard address. |

## Patterns That Work
- Home-profile auto-import only covers `profilesBasePath/<username>/<profileName>/`. Files under `shared/` are NOT auto-imported — they must be explicitly imported by user profile files (e.g., via `import.nix`). Files under `shared/lib/` are pure utility libraries, never modules.
- `_class` conditionals for darwin/nixos shared modules — set platform-specific attrs with `lib.optionalAttrs (_class == "nixos")` / `(_class == "darwin")`. Darwin lacks `isNormalUser`, needs `users.knownUsers`, uses `gid = 80` for admin instead of `extraGroups = ["wheel"]`, and has different GC schedule syntax (interval vs dates).
- SSH into target machines to get actual journal logs rather than guessing from deploy output
- Building locally with `nix eval` to inspect generated configs (TOML, systemd units)
- Running the service binary locally against the generated config to reproduce errors

## Patterns That Don't Work
- Speculating about config issues without checking actual server logs — the deploy output only shows systemd wrapper messages, not the actual service error
- Assuming config parsing is the issue when traefik exits fast — port conflicts also cause instant exit

## Domain Notes (srvos)
- srvos `common` sets: networking.useNetworkd (mkDefault true), firewall.allowPing, stopIfChanged for networkd/resolved, nix optimise/trusted-users/daemon scheduling, userborn, initrd.systemd, boot.tmp.cleanOnBoot, openssh hardening, sudo.execWheelOnly, serial console.
- srvos `common` does NOT set: networking.nftables, programs.nano.
- srvos `mixins-nix-experimental` sets: nix.package = nixVersions.latest, auto-allocate-uids, cgroups, fetch-closure, recursive-nix, ca-derivations, impure-derivations, blake3-hashes.
- srvos `mixins-trusted-nix-caches` adds: nix-community, garnix, numtide cachix as trusted-substituters.
- Our `networking.useNetworkd = false` (no mkDefault) overrides srvos's mkDefault true — we use NetworkManager.

## Domain Notes
- **Fish 4.3 frozen theme migration**: Fish 4.3 auto-generates `~/.config/fish/conf.d/fish_frozen_theme.fish` and `fish_frozen_key_bindings.fish` when upgrading, migrating universal vars to globals. These files set DEFAULT colors that load via conf.d BEFORE config.fish, stomping on home-manager's custom theme. Fix: delete the files and set ALL fish_color_* variables (including pager colors) in interactiveShellInit so nothing falls through to defaults.
- **async-prompt + starship incompatibility**: fish async-prompt plugin spawns a non-interactive `fish -c` subprocess to render the prompt. Since `interactiveShellInit` (where starship inits) is guarded by `status is-interactive`, the subprocess never loads starship and renders the default fish prompt instead. Starship already handles slow modules asynchronously — async-prompt is redundant and harmful. Don't use them together.
- ollama model-pull service needs HOME set — the ollama binary panics with `$HOME is not defined` if HOME isn't in the systemd environment. Fixed in modules/ollama/default.nix by adding `HOME = "/var/lib/ollama"`.
- vLLM on aspen1 uses Docker image `kyuz0/vllm-therock-gfx1151:latest` which is broken (undefined symbol: rsmi_is_P2P_accessible). The llm-gptoss service has autoStart=false but the unit was still cycling.
- aspen1/aspen2 are Framework Desktop with AMD Ryzen AI MAX+ 395, Radeon 8060S (gfx1151), 128GB unified memory. Kernel 6.18.2. TTM params allocate ~124GB as GPU VRAM.
- qwen3.5:122b (122B-A10B MoE) = 81GB on ollama. Fits in the 124GB VRAM allocation with room for KV cache.
- llm-agents.nix (numtide) is client-side tooling only — coding agents, not model serving. `qwen-code` talks OpenAI-compatible API, can point at local ollama.
- Project uses clan-core framework for NixOS infrastructure management
- Tag-based service deployment (all, tailnet, dev, desktop, etc.)
- Services are configured in `inventory/services/` and modules in `modules/`
- Secrets managed via SOPS with age encryption
- britton-desktop has Tailscale Serve manually configured (not in NixOS config) — can conflict with Traefik port 443
- The tailscale-traefik module's `static.settings`/`dynamic.settings` were wrong options (never existed in nixpkgs); fixed to `staticConfigOptions`/`dynamicConfigOptions` in commit 20ae2dc
- Traefik is v3.6.10; has deprecated options (disablePropagationCheck → propagation.disableChecks, delayBeforeCheck → propagation.delayBeforeChecks)
- **Darwin/macOS support**: clan-core produces `darwinConfigurations` output but `parts/clan.nix` must explicitly inherit it. Set `machineClass = "darwin"` in the machine definition. nix-darwin is already a transitive dep of clan-core.
- macOS machines need local-path flake inputs (wrappers, clonadic) rsynced and git-init'd on the target since `specialArgs` references them for all machines.
- First darwin-rebuild must be run locally on the Mac: `nix shell nixpkgs#git -c sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#britton-air`
- britton-air gets DHCP — IP can change (was .60, moved to .54). Consider static lease or Tailscale hostname for deploy target.
- Darwin machines need `system.stateVersion = 6` and `system.primaryUser` set explicitly.
- `claude-code-bin` only exists for linux in nixpkgs; darwin has `claude-code` instead.
- The `all` tag (all.nix) has NixOS-specific options (boot, systemd, networking.nftables, etc.) — can't be applied to darwin machines. Roster requires `all` tag, so home-manager for darwin needs a different approach.
## 2026-03-12 - Exports Cleanup Completed

Successfully removed all dead `exports.instances or {}` consumer code from 12 clan service modules as requested:

### Fixed Modules

1. **prometheus**: Removed `llmScrapeConfigs` block that read exports.instances, updated `allConfigs` to not include it
2. **grafana**: Removed `prometheusFromExports`, `lokiFromExports`, and `lokiDatasourceFromExports` blocks, simplified to use explicit settings only
3. **loki**: Removed `lokiFromExports` in promtail role, removed `exports` parameter from promtail perInstance
4. **llm**: Removed `llmFromExports` and `ollamaFromExports` blocks in client role, removed `exports` parameter from client perInstance  
5. **homepage-dashboard**: Removed entire `discoveredServices` block and all related discovery code, simplified to just use local services
6. **cloudflare-tunnel**: Replaced `exports.instances or {}` with `{}` in autoIngress resolution, added TODO comment for upstream clan-core API
7. **tailscale-traefik**: Simplified `portFromExports` function to just return null, letting it fall back to `portDetectors`

### Preserved Export Producers
- All `exports.serviceEndpoints.*` assignments were kept unchanged in all modules (prometheus, grafana, loki, llm, vaultwarden, etc.)
- These are the correct producers that upstream clan-core collects

### Pattern Applied
- `exports.instances or {}` always returns `{}` because upstream uses scope-keyed exports, not `exports.instances`
- Replaced all consumer blocks with their default/fallback values
- Removed unused `exports` parameters only where they were only used for dead consumer code
- Kept `exports` parameters where modules SET exports.serviceEndpoints (producer side)

The cleanup removes all dead code that silently returned empty objects, making the modules use their explicit configuration instead of false auto-discovery.