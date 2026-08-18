## Context

The replica module currently hard-codes `britton-desktop` in its pure validation core. Its imperative shell already creates an instance-specific Clan key and lowers a native-only Radicle service. `aspen3` has tailnet address `100.108.13.4`, ZFS pool `zroot`, active Prometheus services, and no listener on port `8776`.

Completion means `aspen3` runs a persistent native-only node for the exact governed public and private sets. The node must use a new fingerprint-pinned identity and a dedicated quota-bound dataset. A user Radicle profile, reused node identity, root-filesystem state, wildcard listener, or HTTP service is false completion.

## Decisions

### Decision: Select host facts from an exact reviewed matrix

**Choice:** Keep validation pure. Select immutable target, address, failure-domain, and dataset facts by `expectedHost`. Reject hosts outside `britton-desktop` and `aspen3`.

**Rationale:** This choice reuses one security boundary without accepting arbitrary inventory values. It also keeps host admission explicit and testable.

### Decision: Use a separate service instance on `aspen3`

**Choice:** Add a new `radicle-seed-replica` instance for `aspen3`. Give this instance a separate Clan generator and pinned fingerprint.

**Rationale:** The existing module names key generators by service instance. Separate instances prevent key and variable-path collisions across machines.

### Decision: Keep the existing exact repository policy

**Choice:** Seed the same four public RIDs and the reviewed private pilot RID. Keep HTTP and HTTPS disabled.

**Rationale:** This change adds availability. It does not admit another repository or widen publication.

### Decision: Authorize Aspen3 in the private pilot identity

**Choice:** Add the fingerprint-pinned `aspen3` node DID to the non-secret fixture's private allow set. Keep the denied client absent.

**Rationale:** Radicle private visibility rejects seed identities outside the identity document. Machine policy cannot bypass this protocol boundary.

### Decision: Use bounded local ZFS state

**Choice:** Mount `zroot/radicle-seed` at `/var/lib/radicle`. Set a `64G` quota and `128K` record size.

**Rationale:** The dataset bounds replica growth and separates repository state from the workstation root dataset.

### Decision: Prove identity separation across all seed nodes

**Choice:** Reject the Aspen1 fingerprint in module validation. Add production checks that require the `britton-desktop` and `aspen3` fingerprints to differ.

**Rationale:** A copied replica key would collapse machine identity and weaken incident isolation.

### Decision: Recover through a new verified transaction

**Choice:** Disable the node unit's internal `Restart=` path. Let the persistent policy timer start a failed node through its identity prerequisite.

**Rationale:** Systemd internal restarts do not replay prerequisite units. Direct verification inside the Radicle confinement root is known to reject startup.

## Functional core and imperative shell

The pure validation core selects reviewed host facts and returns stable diagnostics. Deterministic Nix checks cover accepted and rejected settings. Clan key generation, ZFS creation, deployment, synchronization, and live inspection form the imperative shell.

## Risks / Trade-offs

- `aspen3` is mobile and can suspend on battery. The service adds capacity but does not establish geographic or power independence.
- The tailnet address is an admission fact. An address change requires a reviewed configuration update.
- Repository state is disposable replicated state. This change does not add another backup authority.

## Adversarial audit

A primary `radicle-node` instance was rejected because it carries HTTP, backup, and bootstrap-specific policy. A host-specific module fork was rejected because it duplicates security logic. The selected matrix design can still fail if identity uniqueness is not checked outside one instance, so the production check covers both replicas.
