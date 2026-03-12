# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-03-11 | user | `system.etc.overlay.enable = true` without `services.userborn.enable = true` broke passwd database — user disappeared from `/etc/passwd`, `sudo: you do not exist` | Overlayfs `/etc` REQUIRES userborn. Never enable overlay without also enabling `services.userborn.enable = true`. Or just don't use overlay `/etc` — the benefit is marginal. |
| 2026-03-12 | self | Created `niri-keybinds.nix` as a plain function `{ config, pkgs, lib }:` directly in the `noctalia/` profile directory. Clan-core auto-imports all `.nix` files in a profile dir as modules, so it tried to pass module args (`inputs` etc.) to the function → crash. | Plain Nix data/function files that aren't modules must go in a subdirectory (e.g., `lib/` or `noctalia-sections/`) to avoid auto-import. Only put actual NixOS/HM modules directly in profile directories. |

## User Preferences
- (accumulate here as you learn them)

## Domain Notes (continued)
- **Screenshot flakiness on niri**: Two causes. (1) `grim` uses `zwlr_screencopy` which synchronously blocks niri's compositor thread for ~45ms on NVIDIA 3840x2160@240Hz (~10 dropped frames = visible freeze). niri's built-in `screenshot-screen` action is faster (~27ms) since it skips the Wayland client round-trip. (2) `screenshot-region`'s `flock -n` held the lock for satty's entire lifetime, so re-triggering right after closing satty silently exited. Fixed by replacing flock with `pkill -x satty`.
- britton-desktop: NVIDIA RTX (PCI 10DE:2C02) card2 DP-3 3840x2160@240Hz, AMD iGPU (1002:13C0) card1. NVIDIA driver 580.126.18 open kernel module.
- lisgd-niri service crash-loops continuously on britton-desktop (no touchscreen device found) — needs a condition or disable.

## Reference Repos
- **Mic92/dotfiles**: Clan-core infra, srvos, ZFS-first, borgbackup w/ ZFS snapshots, sops-nix, zerotier+wireguard mesh, promtail→loki, buildbot CI, limine secure boot via clan vars, update-prefetch (hourly background pull of next system), nix-index-database/comma, treefmt-nix comprehensive formatter, FHS compat (envfs + nix-ld), iroh-ssh module, TPM-based SSH agent, keyd, data-mesher

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

## Patterns That Work
- SSH into target machines to get actual journal logs rather than guessing from deploy output
- Building locally with `nix eval` to inspect generated configs (TOML, systemd units)
- Running the service binary locally against the generated config to reproduce errors

## Patterns That Don't Work
- Speculating about config issues without checking actual server logs — the deploy output only shows systemd wrapper messages, not the actual service error
- Assuming config parsing is the issue when traefik exits fast — port conflicts also cause instant exit

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
