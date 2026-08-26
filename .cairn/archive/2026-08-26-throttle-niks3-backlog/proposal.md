## Why

A combined fleet rebuild left 2,643 pending niks3 paths on `britton-desktop`, 78 on Aspen1, and 57 on Aspen3. The current eight-upload concurrency overloaded experimental RustFS object operations. Celld lease writes became ambiguous and the Aspen1 node self-fenced.

## What Changes

- Limit each niks3 uploader to one concurrent upload.
- Keep the durable SQLite queue, socket activation, authentication, and integrity verification unchanged.
- Add a generated configuration check for the bounded worker count.
- Exercise an existing queue on one node and record RustFS, niks3, and Celld behavior.

## Impact

- **Files**: `inventory/services/services.ncl`, `flake-outputs/_module-checks.nix`, `.cairn/changes/throttle-niks3-backlog/`, and the accepted RustFS build-cache specification.
- **Runtime**: Upload throughput decreases. One large store path can still exceed a Celld lease-write budget, so runtime evidence records recovery rather than continuous availability.
- **Authority**: No credential, bucket, token, or firewall authority changes.
