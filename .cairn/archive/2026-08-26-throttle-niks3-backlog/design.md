## Context

Every fleet node stores completed Nix paths in a durable local SQLite queue. Each uploader currently starts eight concurrent uploads against one niks3 server and one experimental RustFS cluster.

A large rebuild activated multiple queues together. RustFS returned timeouts, `SlowDown`, read-quorum errors, and temporary 503 responses. Celld correctly self-fenced when it could not renew its lease.

## Decisions

### Decision: Use one upload worker per node

**Choice:** Set `maxConcurrentUploads` to one for all three uploaders.

**Rationale:** A single worker preserves queue progress while bounding each node's immediate pressure. Three active nodes can still produce three concurrent uploads, so the system retains fleet parallelism.

### Decision: Preserve every queued path

**Choice:** Do not clear or rewrite any uploader SQLite database. Exercise only one node's queue during acceptance.

**Rationale:** The queues are the durability boundary for completed builds. Dropping entries would hide the overload instead of fixing it.

### Decision: Keep socket activation and integrity verification

**Choice:** Retain the active socket, shared API token, signed niks3 service, and S3 integrity verification.

**Rationale:** The failure is load shaping, not authority or correctness. Narrowing unrelated controls would weaken the accepted cache design.

## Risks / Trade-offs

- A large queue takes longer to drain.
- Three nodes can still upload at once during normal operation.
- One large store path can still delay Celld lease writes and cause a designed self-fence.
- This change does not prove RustFS behavior under unlimited load.
