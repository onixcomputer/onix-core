# Design: Kiln-on-Aspen private canary

## Goal and evidence

The goal is one operator-controlled Kiln callback hosted by Aspen on `britton-desktop`, with its workflow effect routed through Lattice.

Completion requires all of these observations:

- Onix Core builds exact pinned Aspen, Kiln, and Lattice packages.
- The Kiln host bridge creates the reviewed Unix socket and admits the exact profile.
- Aspen executes `kiln-aspen-extension` through its bounded native-process executor.
- Lattice observes the exact workflow request and returns a bounded terminal observation.
- Aspen materializes that observation for the callback before completion admission.
- Kiln records the exact terminal state or `Unknown`; it never infers success.
- Missing sockets, changed profiles, malformed frames, and unavailable providers fail without fallback.
- The current Seaglass broker route remains unchanged.

A package build, a socket file, `LocalAspenService`, Aspen test support, or a recording-only effect port is not completion evidence.

## Search registry

The architecture audit used serial lenses because subagent consent was not granted. The passes are therefore correlated.

| Family | Mechanism | State | Evidence or blocker |
|---|---|---|---|
| Existing broker adapter | Add Aspen arguments to the current Seaglass adapter command | Falsified | Kiln requires a Unix endpoint, but Aspen publishes no matching daemon. |
| Local simulation | Serve `LocalAspenService` from Onix Core | Falsified | Kiln documents this service as simulation; it does not use Aspen's host. |
| Test-support wrapper | Package the archived cross-repository harness | Falsified | The harness imports Aspen test support and uses in-memory recording adapters. |
| Separate host bridge | Publish a Kiln-owned bridge that composes the Aspen host and Lattice effect adapter | Selected | It preserves protocol ownership and keeps concrete composition at the deployment edge. |

## Ownership and dependency direction

Kiln owns CI decisions, the `kiln.aspen-runtime.unix-request.v2` protocol, callback semantics, reconciliation, and terminal meaning.

Aspen owns native callback execution, bounded process mechanics, materialization, lifecycle admission, and generic effect routing.

Lattice owns workflow execution, persistence, and bounded workflow observations.

Onix Core owns exact package pins, system users, sockets, service ordering, resource limits, machine selection, and canary receipts.

Dependencies point inward through published contracts. Aspen does not depend on Kiln. Lattice does not depend on Kiln or Aspen.

## Upstream contract gates

The reviewed Aspen revision exposes `NativeSystemExtensionService`, but no Unix listener or product host binary.

The reviewed Kiln revision exposes `UnixAspenServiceTransport`, but no server implementation. Its only concrete Aspen service is `LocalAspenService`.

Kiln also has no concrete `AspenWorkflowTransportPort` or `AspenRemoteTransportPort` outside tests.

Aspen's `CanonicalEffectCompletion` contains an output reference, not the exact provider output bytes. Kiln must classify that completion as `Unknown` because it cannot inspect terminal meaning.

The selected dependency order is:

1. Aspen adds a generic, bounded materialized effect-completion contract.
2. Kiln adds the host bridge and a concrete Lattice workflow effect adapter.
3. Onix Core pins those revisions and enables the separate canary module.

The reviewed Lattice contract revision `70496e67c7fd4a8b05914161a8e09de2759bebc8` does not build the full application. Onix Core therefore pins deployable runtime revision `c513d94d89e901ffa56ae67f375f973e55958e42`. No workflow contract, transport, handler, or handler contract path changes between those revisions. The Kiln profile keeps the exact `70496e67...` contract identity while the service package uses `c513d94...`.

Kiln host revision `69c0a6ac454d7291e4aed12fd72a6f2c31636e76` supplies the deployable standalone composition. Its internal protocol dependency remains pinned to `42eabcb21385a436ddc044fb7034b8cdaec7b8a0`.

## Canary composition

The new module remains disabled by default. It does not modify `services.radicle.ci.broker` or its existing Seaglass trigger.

When enabled, the module creates separate service users for the Aspen host bridge and Lattice workflow exchange. A shared socket group grants only the required local connection paths.

The Lattice service starts first and owns its workflow socket and state root. The Kiln host bridge then starts with:

- the exact Kiln Aspen profile;
- the exact Kiln extension executable;
- the exact Aspen host cohort;
- the admitted Lattice route profile;
- bounded state and diagnostic roots; and
- one explicit Aspen service socket.

An operator-only one-shot client submits the controlled canary. No Radicle broker trigger targets this socket during the first stage.

## Failure and uncertainty

A failure before Aspen accepts an operation is retryable only when the typed outcome says so.

A disconnect after acceptance remains `Unknown` until exact reconciliation. The module never starts the Lattice or direct adapter as a fallback.

The Lattice server connection bound equals the host request bound multiplied by one dispatch plus the provider poll bound. This relation prevents the server from stopping before the host consumes its admitted poll budget. The result must remain within Lattice's contract maximum.

The first canary keeps Aspen's process-local value durability non-claim. The host bridge must refuse restart recovery while unresolved operations exist.

## Adversarial audit

Focused checks must reject:

- a changed Aspen, Kiln, or Lattice revision;
- a legacy callback or Unix protocol;
- a non-socket endpoint;
- a wildcard socket permission;
- shared state roots between services;
- missing provider completion bytes;
- an automatic fallback command;
- enablement without all required packages; and
- any mutation of the existing Seaglass broker trigger.

## Evidence boundary

The receipt can claim only a private, local, process-scoped canary. It cannot claim production availability, global durability, CI correctness, workflow correctness, host sandboxing, or release eligibility.
