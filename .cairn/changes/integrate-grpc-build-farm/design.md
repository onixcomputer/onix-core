## Context

The repository currently generates SSH builders from typed inventory and deploys Niks3 with a separate RustFS process. Aspen1 is the sole admitted managed Linux builder; Aspen2 was removed from the SSH target list to avoid reciprocal dispatch. Niks3's existing post-build queues are maintenance-gated because uncontrolled cache traffic previously interfered with coordination services.

## Decisions

### Decision: Shared scheduling without recursive remote builds

**Choice:** Run the scheduler and Envoy on Aspen1, with Aspen1 and Aspen2 as workers. Worker Nix daemons have no remote builders. Clients `bonsai`, `aspen3`, and `britton-desktop` use one gRPC endpoint per admitted system; external SSH routes remain independent. Bonsai was already included when the user replaced `britton-fw` with Bonsai, so the final client set contains three distinct machines.

**Rationale:** Central admission permits the second worker without the reciprocal dispatch cycle. No GPU compute service or additional architecture is admitted by this change.

### Decision: Explicit authenticated trust boundaries

**Choice:** Use an offline shared Clan-vars CA and distinct per-machine client, worker, and balancer certificates. Do not deploy the CA signing key. Authorize exact certificate identities, require authenticated privileged build access, and bind worker ports to Tailnet addresses.

**Rationale:** Build-hook clients upload unsigned paths and therefore require trusted Nix store access. A private network alone does not replace identity authorization.

### Decision: Automatic farm publication is a separate policy

**Choice:** Farm daemons publish to the existing dedicated cache with one concurrent upload per worker. Upgrade only the cache input required by the farm API. Keep the existing SQLite hooks and maintenance guards disabled by default.

**Rationale:** Cross-worker scheduling requires promptly available outputs. The user explicitly authorized this change in publication policy; old maintenance queues must not drain as a side effect.

### Decision: Preserve the pinned evaluator ABI

**Choice:** Compile one gRPC plugin against the exact component libraries and compatible package set of the pinned Nix fork. Carry a narrow compatibility patch for the fork's Nix 2.36 grouped `FullInputs` API; keep the upstream package tests enabled.

**Rationale:** A plugin matching only the nominal Nix version is insufficient evidence of C++ ABI compatibility.

### Decision: Repair desktop SDK consumers without repinning

**Choice:** The authorized deployment follow-up carries three source patches in `pkgs/tenstorrent-compat`: rebase fetch-queue diagnostics, migrate RWKV tensor specifications, and migrate llama.cpp Metalium headers and namespaces to the already-pinned TT-Metal 0.77 API. One package-set adapter supplies all four repository consumers, including the exported RWKV evidence package and its diagnostic runtime.

**Rationale:** These existing desktop packages prevented the complete system build. Retain the dedicated package authority, all input revisions, diagnostics, tensor layouts, Blackhole support, and Qwen's exclusive ownership of the two P150 cards. Do not conceal the failures by removing packages or enabling retired model services.

**Verification:** Both RWKV runtimes pass their host self-tests. The Metalium-linked llama.cpp library passes immediate dynamic-symbol resolution and a host numeric API call inside a namespace without accelerator devices. Package checks remain enabled. This is build and host-API evidence, not a new hardware inference admission.

## Risks / Trade-offs

- Aspen1 remains the scheduler, cache metadata, and ingress failure domain. This change does not claim high availability.
- Two workers may publish simultaneously, each with concurrency one. The isolated RustFS endpoint protects Celld's storage authority but does not eliminate shared host resource pressure.
- Certificate rotation requires regenerating the CA's dependent leaf certificates when rotating the CA. Private keys must remain in Clan secret storage.
- Repository integration and isolated smoke evidence do not imply production deployment. Activation must bring up cache and workers before switching clients.
- Niks3 moves from 1.8.0 to 1.13.0 for scheduler leases and acknowledged streaming pushes. Back up its database before activation, deploy the server before clients, and do not downgrade a migrated database blindly.

## Verification

`evidence.json` records the pinned-runtime build, four passing upstream unit-test groups, five focused fleet checks, generated service-unit builds, and certificate-generator smoke results. The complete upstream four-VM farm scenario passed all 21 subtests using the fleet Nix and packaged plugin, with the cache server explicitly pinned to the new Niks3 version. The fixture's OIDC and second scheduler are additional upstream coverage, not enabled fleet features. That isolated receipt predates production credential generation and the removal of `britton-fw`; consult `deployment-evidence.json` for the current client scope, production preparation, and activation status.
