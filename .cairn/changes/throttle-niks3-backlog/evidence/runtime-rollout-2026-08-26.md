# niks3 backlog throttle runtime evidence

Date: 2026-08-26

## Starting state

The durable uploader databases contained:

- `britton-desktop`: 2,643 queued store paths;
- Aspen1: 78 queued store paths;
- Aspen3: 57 queued store paths.

The prior configuration allowed eight concurrent uploads per node. Concurrent backlog workers caused RustFS timeouts, `SlowDown`, read-quorum errors, and Celld self-fencing.

## Static and build evidence

The change passed:

- niks3 positive and negative settings checks;
- the generated fleet check, including `maxConcurrentUploads = 1` on all three nodes;
- complete NixOS builds for Aspen1, Aspen3, and `britton-desktop`;
- Cairn validation before deployment.

All three deployed systemd units contain `--max-concurrent-uploads 1`. The batch size, durable SQLite path, API token, socket activation, and S3 integrity verification remain unchanged.

## Bounded queue exercise

Only the Aspen3 uploader was started. The other two uploader sockets and services remained stopped.

The Aspen3 queue decreased from 57 to 31 rows. The hook removed 26 paths that normal Nix garbage collection had already removed. It did not manually clear any live queue row. The remaining paths stayed in SQLite when the worker stopped.

The worker processed one upload request at a time. One request expanded to uncached closure paths, including a 98.1 MB firmware path. During that large upload:

- all RustFS health endpoints continued to return HTTP 200;
- both Site Celld endpoints continued to return HTTP 200;
- niks3 continued to return HTTP 200, with increased latency;
- the Aspen1 lab Celld node self-fenced and was unavailable for five bounded samples.

The uploader was stopped. A controlled sequential RustFS restart cleared in-flight distributed writes. The lab Celld node then reacquired authority.

Three later samples returned HTTP 200 for RustFS, Aspen1 lab Celld, both Site Celld endpoints, and niks3. Lab Celld response time stayed below 0.34 seconds in those samples.

## Final state

- All three generated upload units use one concurrent worker.
- All three socket units are active.
- All three upload services are idle and socket-activated.
- RustFS, Kache, niks3, lab Celld, and both Site Celld endpoints are active.
- The durable desktop, Aspen1, and remaining Aspen3 queues were not cleared.

## Non-claims

One worker reduces amplification but does not guarantee continuous Celld availability during one large closure upload. This evidence proves bounded queue progress and observed recovery only. It does not prove unlimited RustFS load, a maximum object size, complete backlog drain, or long-duration availability.
