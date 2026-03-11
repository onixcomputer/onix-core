# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-03-11 | user | `system.etc.overlay.enable = true` without `services.userborn.enable = true` broke passwd database — user disappeared from `/etc/passwd`, `sudo: you do not exist` | Overlayfs `/etc` REQUIRES userborn. Never enable overlay without also enabling `services.userborn.enable = true`. Or just don't use overlay `/etc` — the benefit is marginal. |

## User Preferences
- (accumulate here as you learn them)

## Domain Notes (continued)
- **Screenshot flakiness on niri**: Two causes. (1) `grim` uses `zwlr_screencopy` which synchronously blocks niri's compositor thread for ~45ms on NVIDIA 3840x2160@240Hz (~10 dropped frames = visible freeze). niri's built-in `screenshot-screen` action is faster (~27ms) since it skips the Wayland client round-trip. (2) `screenshot-region`'s `flock -n` held the lock for satty's entire lifetime, so re-triggering right after closing satty silently exited. Fixed by replacing flock with `pkill -x satty`.
- britton-desktop: NVIDIA RTX (PCI 10DE:2C02) card2 DP-3 3840x2160@240Hz, AMD iGPU (1002:13C0) card1. NVIDIA driver 580.126.18 open kernel module.
- lisgd-niri service crash-loops continuously on britton-desktop (no touchscreen device found) — needs a condition or disable.

## Reference Repos
- **Mic92/dotfiles**: Clan-core infra, srvos, ZFS-first, borgbackup w/ ZFS snapshots, sops-nix, zerotier+wireguard mesh, promtail→loki, buildbot CI, limine secure boot via clan vars, update-prefetch (hourly background pull of next system), nix-index-database/comma, treefmt-nix comprehensive formatter, FHS compat (envfs + nix-ld), iroh-ssh module, TPM-based SSH agent, keyd, data-mesher

## Patterns That Work
- SSH into target machines to get actual journal logs rather than guessing from deploy output
- Building locally with `nix eval` to inspect generated configs (TOML, systemd units)
- Running the service binary locally against the generated config to reproduce errors

## Patterns That Don't Work
- Speculating about config issues without checking actual server logs — the deploy output only shows systemd wrapper messages, not the actual service error
- Assuming config parsing is the issue when traefik exits fast — port conflicts also cause instant exit

## Domain Notes
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
