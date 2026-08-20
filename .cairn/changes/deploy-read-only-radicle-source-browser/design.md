## Context

The current public gateway exposes upload-pack for exact admitted RIDs. The route set rejects receive-pack, APIs, root paths, and unknown repositories.

A source browser adds public content exposure and generation effects. It must not inherit repository admission from directory presence or renderer discovery.

## Completion Contract

Completion means one exact admitted public RID and Git object produces a bounded immutable static snapshot. Nginx serves only the accepted browser prefix and exact snapshot paths.

A dynamic working-tree view, ambient scan, private repository, copied Radiant Forge code, writable route, or unenforced limit is false completion.

## Dependencies

Implementation is blocked until OnixOS change `declare-read-only-radicle-source-browser` publishes its accepted portable contract.

The existing Radicle bootstrap receipt and exact RID catalog remain prerequisites. Bounded Exec, Bounded Tree, and durable publication keep their product-neutral authority.

## Decisions

### Decision: Select a licensed component through a capability matrix

**Choice:** Review published components before new implementation. Record source, immutable revision, license, supported views, object formats, limits, output shape, and authority needs.

A component is acceptable only when a narrow wrapper can satisfy every accepted OnixOS requirement. Otherwise the change stops with an exact blocker.

**Rationale:** Reuse reduces implementation risk. A license or feature mismatch cannot be hidden by the wrapper.

### Decision: Publish static exact-object snapshots

**Choice:** Generate HTML and raw artifacts for one admitted RID and exact tagged Git object. Store each result under an immutable snapshot identity.

**Rationale:** Static publication removes runtime Git parsing from public requests and gives rollback one exact target.

### Decision: Keep source observation read-only

**Choice:** The generation shell opens one explicitly selected local Radicle repository through read-only authority. It resolves one exact object and creates a separate bounded materialization.

The renderer receives no delegate key, CI key, canonical-ref authority, receive-pack path, or mutable repository handle.

**Rationale:** Rendering needs bytes, not repository governance.

### Decision: Bound generator and output mechanics

**Choice:** Run an external renderer through Bounded Exec. Supply explicit argv, environment, working directory, deadline, capture, and teardown limits.

Admit output with Bounded Tree. Check member count, depth, path safety, file size, total bytes, types, and exact manifest before publication.

**Rationale:** Renderer behavior is an effect. A successful exit does not prove safe or complete output.

### Decision: Publish immutable trees before current pointers

**Choice:** Publish the complete admitted snapshot first. Publish or replace one small current-pointer artifact only after snapshot validation succeeds.

The pointer binds RID, tagged Git object, snapshot BLAKE3, route-profile BLAKE3, and generation receipt BLAKE3.

**Rationale:** Readers never observe a pointer to an incomplete snapshot. Rollback selects an earlier admitted snapshot.

### Decision: Keep public routes default-deny

**Choice:** Add one distinct browser prefix. Generate Nginx locations only for exact admitted RIDs and selected snapshot paths.

Unknown RIDs, root enumeration, receive-pack, mutation verbs, unsafe paths, and undeclared routes return the existing rejection class.

**Rationale:** The browser must not widen the smart HTTP route or repository set.

### Decision: Keep navigation script independent

**Choice:** Core navigation uses ordinary server-rendered links and works without client scripts. Initial deployment serves no executable client code.

**Rationale:** This limits policy, supply-chain, and content-security scope for the first public pilot.

## Functional Core and Imperative Shell

A pure core validates the selected OnixOS contract, source observation, route inventory, output manifest, publication plan, pointer transition, and receipt facts.

The shell owns Radicle storage reads, materialization, renderer execution, output-tree observation, durable publication, Nginx reload, probes, monitoring, and rollback effects.

## Composition Root

The NixOS module selects the concrete renderer adapter, Bounded Exec adapter, Bounded Tree observer, durable publisher, static server, and monitoring hooks.

No adapter defines repository admission or route policy.

## Evidence

The generation receipt binds source RID, tagged Git object, source snapshot BLAKE3, renderer source and executable identities, limits, output manifest, and snapshot identity.

The deployment receipt binds the accepted OnixOS policy, published snapshot, current pointer, exact HTTPS routes, negative probes, monitoring, rollback target, and non-claims.

## Positive and Negative Verification

Positive fixtures cover every declared view, line anchors, exact-object links, bounded raw content, publication, pointer switch, serving, and rollback.

Negative fixtures cover unknown and private RIDs, missing objects, source drift, renderer drift, timeout, truncation, unsafe trees, oversized output, stale plans, write routes, and copied-source detection.

## Risks and Trade-offs

- Static snapshots can lag mutable refs. The current pointer records one observed exact object.
- Large histories can exceed limits. The generator must truncate or reject according to policy.
- A selected component can lose maintenance. Immutable source and rollback evidence limit change risk.

## Claim Boundary

A passing deployment proves bounded generation and serving observations for one exact snapshot. It does not prove source meaning, renderer correctness, confidentiality, or availability.
