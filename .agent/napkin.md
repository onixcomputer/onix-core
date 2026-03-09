# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|

## User Preferences
- (accumulate here as you learn them)

## Patterns That Work
- SSH into target machines to get actual journal logs rather than guessing from deploy output
- Building locally with `nix eval` to inspect generated configs (TOML, systemd units)
- Running the service binary locally against the generated config to reproduce errors

## Patterns That Don't Work
- Speculating about config issues without checking actual server logs — the deploy output only shows systemd wrapper messages, not the actual service error
- Assuming config parsing is the issue when traefik exits fast — port conflicts also cause instant exit

## Domain Notes
- Project uses clan-core framework for NixOS infrastructure management
- Tag-based service deployment (all, tailnet, dev, desktop, etc.)
- Services are configured in `inventory/services/` and modules in `modules/`
- Secrets managed via SOPS with age encryption
- britton-desktop has Tailscale Serve manually configured (not in NixOS config) — can conflict with Traefik port 443
- The tailscale-traefik module's `static.settings`/`dynamic.settings` were wrong options (never existed in nixpkgs); fixed to `staticConfigOptions`/`dynamicConfigOptions` in commit 20ae2dc
- Traefik is v3.6.10; has deprecated options (disablePropagationCheck → propagation.disableChecks, delayBeforeCheck → propagation.delayBeforeChecks)
