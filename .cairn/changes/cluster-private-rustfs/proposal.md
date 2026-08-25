## Why

The current RustFS deployment creates three independent single-node services. Each service has separate credentials and one local-path volume. The expansion therefore does not provide one namespace, erasure coding across hosts, or node-loss tolerance.

RustFS `1.0.0-rc.2` supports distributed URL endpoints, but upstream marks distributed mode as under testing. The deployment must use one explicit topology and retain clear experimental non-claims.

## What Changes

- Replace the three standalone service instances with one three-machine RustFS cluster instance.
- Give every node the same ordered URL endpoint list and one shared Clan-managed credential file.
- Use the Tailnet addresses for encrypted inter-node transport and interface-scoped client access.
- Add pure topology validation for endpoint count, uniqueness, local membership, paths, ports, and distributed mode.
- Start the cluster on new empty state directories and retain the standalone directories for rollback.
- Require coordinated deployment and live cluster, restart, node-loss, access-control, and S3 checks before acceptance.

## Impact

- **Files**: RustFS schema, topology core, Clan service lowering, Nickel fixtures, module checks, service inventory, generated shared vars, the Aspen1 evaluator compatibility pin, Cairn artifacts, and runtime evidence.
- **Security**: All nodes receive one cluster credential. Ports remain open only on `tailscale0`.
- **Storage**: New cluster data uses dedicated directories beside the retained standalone directories.
- **Availability**: A three-endpoint erasure set is intended to survive one unavailable endpoint. Only a live fault test can support that claim.
- **Testing**: Positive and negative topology tests, Nickel settings checks, machine evaluation, system builds, coordinated deployment, authenticated S3 checks, anonymous rejection, restart recovery, and one-node outage recovery.
- **Non-goals**: This change does not add a load balancer, TLS above Tailnet, geographic independence, backups, or production readiness.
