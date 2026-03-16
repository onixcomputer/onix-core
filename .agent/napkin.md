# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
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
- `settings.json` can stay as read-only symlink — template system doesn't write to it. Noctalia UI settings changes won't persist, but that's acceptable (use Nix for settings, Noctalia for live colours).
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

## Patterns That Work
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