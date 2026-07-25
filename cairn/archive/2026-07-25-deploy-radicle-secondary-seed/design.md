## Context

Aspen1 now serves the governed Bounded Exec pilot over native Radicle and read-only public HTTPS Git. Its bootstrap receipt explicitly denies independent-seed and outage claims. `britton-desktop` is the only currently reachable managed machine outside the `aspen-primary-site` machine/storage boundary; it already provides encrypted backup storage but does not run a Radicle system service.

Completion means a separate system identity on `britton-desktop` selectively stores the exact pilot RID, survives restart, rejects undeclared RIDs and forbidden credentials, and serves the reviewed Git object while Aspen1's native node is stopped. A user Radicle profile, transient node, shared delegate key, unbounded root-filesystem state, or clone that can fall back to public seeds is false completion.

## Decisions

### Decision: Use a separate least-authority replica module

**Choice:** Add `radicle-seed-replica` rather than weakening Aspen1-specific bootstrap validation. The module accepts typed host, deployment, failure-domain, identity, listener, repository, storage, monitoring, and signed-reference facts; it lowers them through the reviewed Radicle service shell and policy reconciler with HTTP disabled.

**Rationale:** Aspen1 recovery, HTTPS, and backup invariants remain stable. The replica has a smaller authority and exposure surface and can evolve independently.

### Decision: Use a new machine-scoped node identity

**Choice:** Generate a distinct Ed25519 Radicle node key through the replica's Clan variable boundary, pin its public fingerprint after generation, and verify that fingerprint before every node start. Never reuse the operator or recovery delegate identities.

**Rationale:** Replication requires node identity, not repository governance. A distinct key prevents seed compromise from authorizing canonical history.

### Decision: Bound state on a dedicated ZFS dataset

**Choice:** Store `/var/lib/radicle` on `datapool/radicle-seed` with an explicit 64 GiB quota and Git-appropriate ZFS defaults. Create the dataset only through a reviewed preflight when absent; declarative mount and service ordering own normal operation.

**Rationale:** The desktop root filesystem is already highly utilized. A dedicated quota prevents replication growth from consuming unrelated workstation or backup capacity.

### Decision: Expose native Radicle only on the tailnet

**Choice:** Listen on `100.110.43.11:8776`, open that port only on `tailscale0`, use `seedingPolicy.default = block`, and reconcile exactly the pilot RID. Do not run `radicle-httpd`, Nginx, Cloudflare, ACME, or a public listener for this replica.

**Rationale:** The immediate availability gate needs a second native seed. A second public HTTPS origin is a separate ingress/failover change and remains a non-claim.

### Decision: Treat machine and service authority separately

**Choice:** The systemd unit uses `ProtectHome`, masks `/run/secrets`, receives one systemd credential for its node key, and has an empty capability bounding set. The receipt claims service-level least authority, not immunity from host-root compromise. User-owned operator material and encrypted recovery artifacts on the workstation are not service inputs.

**Rationale:** The selected machine is an independent machine/storage failure domain, but it is also an operator workstation and backup target. Explicit service and host claim boundaries prevent overstating isolation.

## Functional core and imperative shell

Pure Nix validation checks package version, exact host/target/failure-domain facts, canonical unique RIDs, non-wildcard listener policy, fingerprint shape, signed-reference policy, storage bounds, and forbidden credentials. Pure Nix lowering returns deterministic NixOS configuration. The Clan generator, ZFS preflight, deployment, synchronization, restart, listener inspection, systemd credential loading, and acquisition probes are the imperative shell.

## Positive and negative validation

Positive fixtures instantiate the reviewed package, desktop assignment, dedicated identity, bounded dataset, tailnet listener, default-block policy, exact pilot RID, monitoring, no HTTP, and hardened units. Negative fixtures cover Aspen1 identity reuse, wrong host/target/failure domain, wildcard or loopback listeners, non-tailnet firewall, invalid/duplicate RIDs, weak signed refs, malformed fingerprints, missing monitoring, excessive storage, HTTP/public ingress, and delegate/CI credentials.

## Evidence and non-claims

The deployment receipt binds module policy, package identities, machine and dataset, node ID/fingerprint, exact RID/object, listener/firewall, service hardening, policy reconciliation, restart, Aspen1-off acquisition, undeclared-RID rejection, and explicit non-claims. It excludes private keys, raw environments, user-home content, backup credentials, delegate artifacts, repository content, and unbounded logs.

The receipt does not prove a second public HTTPS origin, geographic/building-power independence, host-root isolation, private confidentiality, repository correctness, delegate availability, CI, canonical-ref enforcement, or release readiness.
