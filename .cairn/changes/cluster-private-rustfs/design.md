## Context

The RustFS module currently lowers one local directory into `RUSTFS_VOLUMES`. It also creates a machine-specific credential generator. The inventory repeats that single-node module as three separate service instances.

RustFS selects distributed erasure mode only when `RUSTFS_VOLUMES` contains URL endpoints on multiple hosts. Every node must receive the same topology and credentials. The pinned release accepts erasure-set sizes from two through sixteen, including three.

The existing `aspen3` and `britton-desktop` services contain standalone metadata. Reusing those directories directly would mix storage modes. Aspen1 is also unavailable through SSH at the start of this change.

## Decisions

### Decision: Use one cluster instance

**Choice:** Define one Clan service instance named `rustfs-cluster`. Assign `aspen1`, `aspen3`, and `britton-desktop` to its server role.

**Rationale:** The instance is the visible composition root. It owns one topology and one authority boundary.

### Decision: Keep topology validation pure

**Choice:** Add a pure Nix topology function. It receives validated settings and returns derived volumes, environment values, and explicit assertions.

**Rationale:** Endpoint policy is deterministic domain logic. The NixOS module remains the imperative deployment shell.

### Decision: Use one endpoint per machine

**Choice:** Configure one three-drive erasure set with these Tailnet URL endpoints:

- `http://100.100.103.95:39000/var/lib/rustfs-cluster`
- `http://100.108.13.4:39000/mnt/usb4-nvme/rustfs-cluster`
- `http://100.110.43.11:39000/datapool/rustfs-cluster`

Each machine binds its Tailnet address and receives the same ordered endpoint list.

**Rationale:** Explicit addresses avoid mDNS and MagicDNS startup dependencies. Tailscale encrypts inter-node traffic and supplies the admitted interface boundary.

### Decision: Share cluster credentials through Clan

**Choice:** Set `share = true` on the cluster generator. Generate one new credential file for the `rustfs-cluster` instance.

**Rationale:** RustFS peers must authenticate with the same root credentials. Separate machine credentials create separate authority domains.

### Decision: Preserve standalone state for rollback

**Choice:** Use new empty `rustfs-cluster` directories. Do not delete or modify the current standalone directories during the cluster pilot.

**Rationale:** Distributed startup must not consume single-node metadata. Retained state supports a bounded rollback.

### Decision: Fail closed on invalid distributed topology

**Choice:** Distributed mode requires at least three unique HTTP endpoints. It also requires a non-wildcard bind address and exact local endpoint membership. Every endpoint must use the configured API port and an absolute path.

**Rationale:** A partial or divergent topology can create independent stores or prevent quorum. Evaluation must reject it before deployment.

### Decision: Coordinate the live cutover

**Choice:** Do not switch a live node until all three machine configurations build and Aspen1 is reachable. Deploy the nodes as one operation, then verify cluster behavior.

**Rationale:** A partial cutover removes the working standalone endpoint without creating an accepted cluster.

## Positive and Negative Validation

Positive tests cover single-node compatibility and a valid three-node topology. Negative tests cover too few endpoints, duplicate endpoints, wildcard binding, a missing local endpoint, a wrong port, malformed paths, and mixed endpoint modes.

Live tests cover shared credentials, one namespace through each node, authenticated object operations, anonymous rejection, coordinated restart, and one-node outage recovery. A failed fault test blocks availability claims.

## Risks / Trade-offs

- RustFS marks distributed mode as under testing.
- Three machines do not provide geographic or building-power independence.
- One endpoint per host couples node and drive failure.
- Client access has no stable load-balanced address.
- Shared root credentials increase the effect of one node compromise.
- Aspen1 reachability and its unrelated `nix-eval-jobs` build failure can block deployment.
