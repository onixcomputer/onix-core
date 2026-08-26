## Why

A single large niks3 closure upload can delay RustFS conditional writes long enough for lab Celld to self-fence. Limiting the uploader to one worker reduces amplification, but it does not isolate coordination authority from cache traffic.

Automatic socket activation also resumes thousands of durable queued paths after any build. Operators need an explicit maintenance boundary before backlog work can start.

## What Changes

- Run niks3 objects in a separate, cache-only RustFS process and data directory on Aspen1.
- Keep Celld and Kache on the existing three-node RustFS cluster.
- Disable automatic niks3 post-build queue activation by default.
- Require an explicit maintenance marker and healthy coordination endpoints before a manual queue drain starts.
- Export queue depth and probe RustFS, Celld, and niks3 endpoints from Prometheus.
- Back up authoritative Celld buckets and niks3 PostgreSQL metadata to `britton-desktop` storage.
- Exercise object and PostgreSQL restoration without changing production authority.

## Impact

- **Files**: `modules/rustfs`, `modules/niks3`, `modules/prometheus`, service inventory, fixtures, generated checks, documentation, and Cairn specifications.
- **Runtime**: niks3 cache objects become disposable isolated state. Existing durable upload queues remain intact but cannot resume automatically.
- **Testing**: positive and negative settings tests, generated configuration checks, three complete machine builds, runtime isolation, backup, restore, and health evidence.
