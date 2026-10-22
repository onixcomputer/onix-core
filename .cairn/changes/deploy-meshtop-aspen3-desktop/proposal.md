# Deploy meshtop on Aspen3 and britton-desktop

## Why

`meshtop` provides a read-only btop-style terminal dashboard over authenticated Iroh, but its standalone source checkout and manual `cargo install` do not survive an Onix system rebuild. Aspen3 and britton-desktop need a reproducible binary, durable agent identities, and one explicitly authorized desktop viewer.

## What Changes

- Import the exact committed meshtop source into a revision-recorded onix-core package through a checked sync script; expose a Linux flake package.
- Enable an Aspen3 NixOS agent with private systemd state. Declare a separately keyed britton-desktop Home Manager user agent, the installed viewer binary, and the two-host roster; do not enable an agent on unrelated machines.
- Pin the desktop viewer's public endpoint ID in each service and the observed public agent IDs in the desktop roster.
- Activate the Aspen3 system through Clan. Install the onix-core-generated desktop user unit and roster independently because the retained lockfile's TT-Metal dependency blocks the complete desktop NixOS build; check authenticated telemetry on both live hosts.

## Impact

- **Owners**: meshtop owns the upstream monitor source; onix-core owns its pinned package, service/profile policy, and rollout evidence. `tenstorrent.nix` owns the unrelated desktop TT-Metal build blocker.
- **Boundaries**: Private endpoint keys never enter Nix evaluation or the store. The desktop unit, roster, and package are live, but the entire desktop NixOS generation has **not** been switched. Iroh's default DNS/relay route depends on external network availability; successful selected-route validation does not establish arbitrary-WAN availability. This does not add process control or grant any Tile session authority.
- **Verification**: Package build, selected machine/profile evaluation, syntax/format and Cairn gates; live system/user service status, stable public IDs, authorized samples from both machines, wrong-viewer denial, and a single-host-offline observation.
