## Why

A combined fleet rebuild left 2,643 pending niks3 paths on `britton-desktop`, 78 on Aspen1, and 57 on Aspen3. The current eight-upload concurrency overloaded experimental RustFS object operations. Celld lease writes became ambiguous and the Aspen1 node self-fenced.

## What Changes

- Limit each niks3 uploader to one concurrent upload.
- Keep the durable SQLite queue, socket activation, authentication, and integrity verification unchanged.
- Add a generated configuration check for the bounded worker count.
- Drain existing queues one node at a time and record RustFS, niks3, and Celld health.

## Impact

- **Files**: `inventory/services/services.ncl`, `flake-outputs/_module-checks.nix`, `.cairn/changes/throttle-niks3-backlog/`, and the accepted RustFS build-cache specification.
- **Runtime**: Upload throughput decreases, but foreground object operations and Celld leases keep capacity.
- **Authority**: No credential, bucket, token, or firewall authority changes.
