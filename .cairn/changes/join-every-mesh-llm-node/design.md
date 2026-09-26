# Design: Join every Mesh-LLM node over its Tailscale invite

## Context

Mesh-LLM 0.72.2 behavior, from the `v0.72.2` source:

- **Startup:** a joiner tries its invite tokens in order and stops at the first that connects, spending up to about 105 s on each unreachable token (`runtime/mod.rs:6229-6271`, `mesh/mod.rs:4933-4987`).
- **After startup:** it re-dials every token every 60 s for as long as it runs (`runtime/mod.rs:6383-6394`).
- **No saved peers:** known peers are not persisted. Only `~/.mesh-llm/key` survives a restart, so a node's invite stays valid while its state directory lives.
- **Self tokens:** a token for the node itself counts as an immediate success at startup (`mesh/mod.rs:8911-8915`).
- **Seeds:** a node with no tokens originates the mesh ID from `--mesh-name` (`runtime/mod.rs:6423-6458`). The ID is the same on every restart.
- **Addresses:** in `mdns` mode with `--bind-ip` set to the Tailscale address, invites and gossip carry only `100.x:47916` (`mesh/mod.rs:575-594`), and relays and STUN stay off.

## Decisions

### Decision: Invite every other node, in a fixed order

**Choice:** A joiner loads `invite-<peer>` for every other machine of its instance: joiners in name order, then the seed.

**Rationale:**
- Any single node can be offline without splitting the mesh, and aspen3 reaches the LAN pair over Tailscale.
- Joiners come first because they are the hosts that stay up. The seed goes last, so an offline seed never delays startup before a reachable joiner.
- The node's own invite is excluded, so a self token cannot end the startup loop early.

### Decision: One shared generator, one prompt per node

**Choice:** `mesh-llm-<instance>-invites` is a shared Clan vars generator with one secret file and one hidden, persisted prompt per node. It is declared on joiners only.

**Rationale:**
- A node's invite is the same for every peer, so it is entered once.
- Adding a node adds one prompt, and every joiner picks the invite up on its next deployment.
- The seed does not load invites, because any token would stop it from originating the mesh ID.

### Decision: Keep the private transport

**Choice:** Keep `--mesh-discovery-mode mdns`, `--bind-ip <tailnet address>` and the fixed UDP port.

**Rationale:** This split is a bootstrap problem, not a transport problem. iroh relays would still need a reachable invite, and the private-mesh requirement (`onix.mesh_llm.private` in the `mesh-llm-sidecar` spec) forbids public relays and STUN.

## Risks / Trade-offs

- Each joiner starts up to about 105 s later for every unreachable invite listed before the first reachable one.
- A node that loses its state directory gets a new key. Its invite must then be re-entered, and every joiner redeployed.
- aspen2 and aspen1 keep their current configuration until their next deployment. The mesh still includes them, because the updated joiners dial them.
