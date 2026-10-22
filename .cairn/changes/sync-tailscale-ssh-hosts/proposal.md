## Why

The brittonr SSH profile contains a small manually maintained host list while Tailscale membership changes at runtime. This omits most visible devices from SSH configuration and leaves stale routes: britton-gpd is assigned Bonsai's address. Existing /etc/hosts synchronization does not produce SSH host entries.

## What Changes

- Deploy a local Tailscale-to-SSH updater through the existing Home Manager SSH profile.
- Include its generated aliases after explicit SSH policy and routing overrides.
- Refresh on user-manager startup and every minute without a Nix rebuild.
- Derive aliases from assigned DNS names, retain offline devices, and preserve the last good file when discovery fails.
- Remove copied Tailscale HostName values while preserving usernames, keys, and intentional LAN/root overrides.

## Impact

- **Source**: `inventory/home-profiles/brittonr/base/ssh.{ncl,nix}`, the focused updater module/script, and isolated behavioral regressions.
- **Activation**: selected user artifacts on britton-desktop and Aspen3; no whole-system or unrelated Home Manager switch.
- **Discovery scope**: each machine's locally visible inventory, not a replicated Britton inventory or a Tailscale admin-API roster.
- **Non-goals**: enabling SSH servers, altering Tailscale ACLs, changing login identities or host-key trust, and replacing /etc/hosts synchronization.
