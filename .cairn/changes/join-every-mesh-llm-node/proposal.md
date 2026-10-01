## Why

The private Mesh-LLM network is split. Every joiner holds a single invite, and it points at the seed, aspen1 (`100.100.103.95:47916`). aspen1 has been offline for two days.

- britton-desktop and aspen2 still reach each other, because the LAN beacon finds peers on their shared LAN.
- aspen3 is now off that LAN. It restarted with nobody reachable, reports no mesh ID and no peers, and serves only its own Lemonade models. `Qwen3.8-27B` is therefore invisible from aspen3, and aspen3's models are invisible from the desktop.

Mesh-LLM 0.72.2 keeps no peer list across restarts. A joiner rejoins only through its invite tokens or LAN discovery, and LAN multicast does not cross Tailscale.

## What Changes

- Each joiner gets one invite per other node of its instance: joiners first in name order, the seed last. Each invite is a separate `--join-file` credential. Mesh-LLM tries the invites in order at startup and re-dials every one of them each minute.
- One shared, prompted Clan vars generator (`mesh-llm-<instance>-invites`) holds one invite per node. It is read from that node's `/api/status` and replaces the per-joiner `join-token` generator.
- The seed keeps no invites: it originates the mesh ID, and the joiners dial it.
- aspen2's mesh bind address moves to its live Tailscale address, `100.82.25.30`.
- The DGX module keeps its single invite through the same list interface.

Transport stays as it is: `mdns` discovery mode, no public relays or STUN, QUIC bound to each node's Tailscale address.

## Impact

- **Files**:
  - `modules/mesh-llm/{default.nix,mk-nixos-config.nix,mk-launch-args.nix}`
  - `modules/dgx-machine/default.nix`
  - `flake-outputs/_mesh-llm-checks.nix`
  - `inventory/services/services.ncl`
  - `vars/`
  - this change
- **Deployment**:
  - britton-desktop from its deployed lineage.
  - aspen3 from the tree it was last deployed from.
  - aspen2 and aspen1 pick the change up on their next deployment. Until then they are reached through the other joiners' invites.
