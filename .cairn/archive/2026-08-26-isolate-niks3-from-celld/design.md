## Context

The distributed RustFS cluster serves coordination state, Kache artifacts, and niks3 objects. Runtime evidence showed that one 98.1 MB niks3 path could keep RustFS health responsive while delaying conditional writes beyond Celld's lease budget.

The fleet has three durable niks3 SQLite queues. Automatic socket activation can resume those queues after an unrelated Nix build. The cache data is replaceable, but Celld coordination state is authoritative.

## Success Contract

The goal is to prevent niks3 object traffic from entering the RustFS process and namespace that serve Celld.

Completion evidence requires:

- a distinct RustFS unit, port, data directory, credentials, and process for niks3 objects;
- no automatic niks3 uploader socket activation or live post-build queue effect;
- a guarded manual drain that rejects a missing maintenance marker or unhealthy endpoint;
- Prometheus queue, availability, and latency evidence;
- off-host object and PostgreSQL backups with successful restore probes;
- complete builds and live service checks on all three nodes.

False completion includes a concurrency-only limit, a longer Celld lease, an unverified backup file, or a second bucket in the same RustFS process.

## Portfolio Search

The search used four correlated serial lenses because subagent consent was unavailable.

| Family | Mechanism | Result |
|---|---|---|
| Concurrency | Limit each uploader to one worker | Falsified as sufficient. One large path still caused self-fencing. |
| Admission | Probe health before each backlog run | Useful guard, but insufficient alone because health can degrade after admission. |
| Lease masking | Increase Celld lease duration | Rejected. It weakens failure detection without isolating the cause. |
| Storage isolation | Use a separate cache-only RustFS process and namespace | Selected. Bulk object operations no longer enter the coordination RustFS process. |

The adversarial audit requires a live large-object upload while every Celld endpoint remains healthy. It also requires negative tests for missing maintenance markers, failed health probes, invalid service names, and absent backups.

## Decisions

### Decision: Isolate by process and namespace

**Choice:** Run a standalone cache-only RustFS service on Aspen1 with its own unit, port, data directory, root credentials, bucket policy, and resource weights.

**Rationale:** A separate bucket does not isolate RustFS scheduling, quorum work, or request locks. A separate process removes niks3 requests from the coordination service path. Cache loss remains recoverable through rebuilds and durable upload queues.

### Decision: Keep uploads operator-admitted

**Choice:** Keep the uploader unit available for maintenance, but remove socket startup and replace the Nix post-build hook with a successful no-op. Require a runtime marker and healthy guard URLs before manual start.

**Rationale:** This preserves durable SQLite queues without allowing an unrelated build or reboot to resume them.

### Decision: Observe through existing Prometheus components

**Choice:** Export queue depth through the node exporter's textfile collector. Use the Prometheus blackbox exporter for RustFS, Celld, and niks3 health and latency.

**Rationale:** These are external observations. They belong in the imperative monitoring shell, not service domain policy.

### Decision: Back up only authoritative state

**Choice:** Back up Celld buckets and niks3 PostgreSQL metadata. Do not back up Kache or isolated niks3 object data.

**Rationale:** Build-cache objects are reproducible. Coordination objects and signing metadata are not equivalent to disposable cache content.

## Risks / Trade-offs

- niks3 cache reads can miss until isolated storage is repopulated.
- Aspen1 remains one physical failure domain for the isolated cache process and PostgreSQL service.
- Resource weights reduce host contention but do not prove a fixed bandwidth ceiling.
- Manual drains need an operator maintenance window.
- Object-level backups do not prove raw distributed RustFS volume restoration.
