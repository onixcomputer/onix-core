## Context

Celld `v0.3.0` runs one Cloudflare-compatible Worker deployment per fleet. Each node stores active SQLite state locally and uses one object-store bucket for deployments, cell replicas, leases, fencing epochs, and peer authentication. The bucket is the fleet authority.

Celld correctness requires conditional create, conditional overwrite, and read-after-write consistency. Its live `diagnose` command passed create, duplicate-create rejection, update, and stale-update rejection through all three RustFS endpoints on 2026-08-25. A separate live probe also proved that a RustFS user with a bucket-scoped policy can pass the same test.

The fleet remains experimental because Celld is alpha software and RustFS distributed mode is experimental in `1.0.0-rc.2`.

## Decisions

### Decision: Align Celld and RustFS failure domains

**Choice:** Run one Celld node on each RustFS host. Each Celld node uses the RustFS endpoint on its own host, while all nodes share one bucket and one Celld credential.

**Rationale:** A host outage removes one compute node and one storage endpoint together. Surviving Celld nodes retain local access to surviving RustFS endpoints without a new load-balancer dependency.

### Decision: Keep storage authority separate

**Choice:** Clan generates one shared Celld AWS credential. A designated Aspen1 oneshot unit uses the existing RustFS administrator secret only to create the bucket, create or update the Celld user, and attach a bucket-scoped policy. The Celld service receives only the dedicated credential.

**Rationale:** Celld treats bucket credentials as fleet administrator authority. Restricting them to one bucket prevents the Worker fleet from controlling unrelated RustFS data.

### Decision: Provision before serving, then tolerate ordering

**Choice:** The designated provisioner performs idempotent bucket, user, and policy reconciliation. Celld services use unconditional restart with a delay that is at least one Celld lease lifetime.

**Rationale:** Clan can switch hosts in different orders. A node that starts before provisioning must fail closed and retry rather than receive broader credentials.

### Decision: Use separate Tailnet listeners

**Choice:** Bind the Worker listener and internal peer/operator listener to each host's Tailnet address. Open both ports only on `tailscale0`, and advertise only the internal Tailnet address.

**Rationale:** Celld does not terminate TLS on its internal listener, and much of its operator API is unauthenticated. The encrypted overlay is the admitted confidentiality and reachability boundary for this lab.

### Decision: Deploy a bounded counter Worker

**Choice:** The Aspen1 provisioner deploys a pinned in-repository counter Worker after storage reconciliation. The Worker owns one named Durable Object and returns its durable counter value.

**Rationale:** Service startup alone does not prove Durable Object storage. A small deterministic Worker provides positive state-transition evidence and supports restart and node-loss tests.

### Decision: Keep domain and effect boundaries visible

**Choice:** Pure Nix helpers validate addresses, ports, bucket names, paths, and designated-provisioner topology. The Clan module shell owns secrets, systemd units, storage provisioning, process execution, and runtime observation.

**Rationale:** Configuration meaning remains deterministic. External storage and deployment effects remain explicit at the module boundary.

## Risks / Trade-offs

- Celld `v0.3.0` is alpha software and is not admitted for hostile multi-tenant workloads.
- RustFS distributed mode remains experimental in `1.0.0-rc.2`.
- Tailnet membership grants access to Celld's internal listener; this change does not add per-peer firewall identity policy.
- One fleet runs one application deployment. Replacing the counter is a fleet-wide application change.
- Bucket-scoped credentials still grant complete authority over this Celld fleet.
- Runtime acceptance does not prove long-duration load behavior, public ingress safety, disaster recovery from total cluster loss, or compatibility with a later Celld release.
