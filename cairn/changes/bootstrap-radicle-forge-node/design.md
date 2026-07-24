## Context

The Radicle forge pilot currently has repository-local publication and consumption plans, but no accepted Onix-managed node exists. Live deployment discovery found that Aspen1 already holds a legacy Radicle node identity, 56 GiB of state, and 6,760 repository stores from an earlier Clan-managed deployment. `onix-core` is the repository that can preserve that state, install reviewed packages, bind the recovered service identity, apply firewall and reverse-proxy policy, deploy through Clan, monitor the unit, and execute backup/restore operations. OnixOS can define portable forge intent and cross-repository acceptance, but it cannot supply evidence for a node that has not first been admitted here.

Completion means `aspen1`, deployed through `root@aspen1.local`, runs a persistent selective Radicle node and a seed-backed HTTPS Git endpoint, survives restart, rejects unsafe configuration, and emits a deterministic bootstrap receipt that downstream Cairns can verify. A local developer profile, transient `rad node start`, unencrypted ad hoc key copy, GitHub-backed proxy, browser-only page, or endpoint without exact-object acquisition is false completion.

## Decisions

### Decision: Bootstrap concrete infrastructure before forge orchestration

**Choice:** `onix-core` packages and deploys the first Radicle node. OnixOS consumes its accepted receipt before admitting catalog entries, additional seed placement, CI, or pilot publication.

**Rationale:** The dependency order must begin with an operational source and synchronization boundary. Otherwise downstream plans can validate strings while no service can publish, seed, clone, monitor, or restore a repository.

### Decision: Aspen1 is the bootstrap host

**Choice:** Assign the initial node to the existing `x86_64-linux` machine `aspen1` and use `root@aspen1.local` for Clan deployment and local runtime probes. Listener addresses and the stable HTTPS origin remain explicit typed policy rather than being inferred from the deployment hostname.

**Rationale:** Aspen1 is already a managed always-on server with persistent storage, monitoring, HTTPS proxy infrastructure, and a reviewed deployment path. Keeping deployment identity separate from client endpoints avoids treating mDNS as public service discovery.

### Decision: Use typed configuration with a thin deployment shell

**Choice:** A Nickel contract validates explicit package version, selected machine, failure-domain label, persistent state path, node mode, seed allowlist, listener policy, HTTPS origin, storage bound, retention policy, backup target, and monitoring settings. Nix lowers validated facts into a service module; Clan deployment and runtime probes remain the imperative shell.

**Rationale:** Admission logic remains deterministic and testable without network or root access. Deployment handles filesystem, secret, process, proxy, firewall, and machine effects without hiding policy in shell commands.

### Decision: Reuse the pinned Nixpkgs Radicle package and service shell

**Choice:** Export the flake-pinned Nixpkgs `radicle-node` `1.9.1` and `radicle-httpd` `0.25.0` packages, then lower Onix policy into the pinned NixOS `services.radicle` module. Keep Onix-owned validation and lowering in pure Nix functions and add only stricter interface-scoped firewall and systemd constraints around the upstream imperative service shell.

**Rationale:** The pinned module already validates generated `config.json`, supplies the node key through a dedicated systemd credential, confines both daemons, persists complete Radicle state, and provides a namespace-correct `rad-system` operator wrapper. Reimplementing those mechanics would expand the trust surface without improving the bootstrap claim.

### Decision: Treat signed-reference `parent` as acquisition policy

**Choice:** Require `minimumSignedRefsFeature = "parent"` in the typed contract and later pass it to exact-object clone/sync probes. Do not claim it is a daemon configuration field; Radicle `1.9.1` implements the feature while the client acquisition command selects the minimum accepted level.

**Rationale:** Conflating a client fetch constraint with node configuration would create a passing configuration check that never exercises replay protection at acquisition time.

### Decision: Admit Radicle `1.9.1` or later and signed-reference feature `parent`

**Choice:** The package check rejects an older Radicle release or a configuration weaker than the named minimum signed-reference feature. Version and feature minima are named policy fields rather than scattered literals.

**Rationale:** The pilot must not deploy below the reviewed replay-protection baseline. Recording the admitted package identity makes later upgrades and incident review explicit.

### Decision: Give the node no repository governance authority

**Choice:** The service receives only its own persistent Radicle node identity and storage permissions. Repository delegate keys, offline recovery authority, CI credentials, deployment credentials, release signing keys, canonical-ref authority, cache administration, and artifact-storage administration are forbidden from the unit and its state directory. Systemd hardening must also prevent access to Aspen1's existing Buildbot, Nix-signing, Cloudflare, Vaultwarden, Matrix, and other co-hosted service credentials.

**Rationale:** Source replication and transport availability do not require repository governance. Compromise of the first public seed must not authorize canonical history changes or privileged builds.

### Decision: Recover and pin Aspen1's existing persistent node identity through Clan

**Choice:** The Aspen1 service instance owns one service-specific Clan generator boundary, but bootstrap deployment re-encrypts the historical Aspen1 Radicle private key into that current machine-scoped variable instead of rotating it. Typed policy pins public fingerprint `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE`; a missing or different identity fails admission. The NixOS Radicle module loads only that private key as a systemd credential, while the node and read-only HTTP daemon receive the public key through a read-only bind.

**Rationale:** Live discovery found 56 GiB and 6,760 repository stores bound to the existing node fingerprint. Silent key replacement would strand that state and change peer identity. Recovering the earlier Clan-encrypted key preserves continuity while the service-specific variable, machine scope, and pinned fingerprint keep it separate from user, delegate, Buildbot, Nix-signing, deployment, and release authority.

### Decision: Start with public pilot content

**Choice:** The bootstrap endpoint admits only explicitly selected public probe or pilot repositories. Private repository hosting remains disabled until enumeration, authorization, storage-operator visibility, and backup confidentiality have separate accepted evidence.

**Rationale:** Radicle selective replication is not encryption at rest, and node operators can read replicated private content. Public bootstrap content proves transport without creating a false confidentiality claim.

### Decision: Expose ordinary Git through a read-only HTTPS boundary

**Choice:** `radicle-httpd` reads local Radicle storage behind the repository's reviewed HTTPS proxy and DNS/TLS path. Direct service listeners remain bound to the declared private interface or loopback unless the typed policy explicitly admits a public protocol listener. Cargo and Nix use the HTTPS Git endpoint; native Radicle peers use the separately declared node endpoint.

**Rationale:** The pilot needs compatibility with ordinary Git clients while keeping HTTP exposure, peer synchronization, and repository authority distinct.

### Decision: Preserve the complete node state and prove restore

**Choice:** Backup includes the Radicle storage and identity material required to recover the same node, repositories, signed refs, issues, patches, identities, and declared custom COB refs. The authoritative backup target must be outside Aspen1's failure domain; Aspen1's local Borg server or another same-host path cannot satisfy recovery. The operator shell creates a bounded backup, verifies a BLAKE3 manifest, restores into a clean test root or replacement unit, and compares declared identities before acceptance.

**Rationale:** Branch-only Git backups omit collaboration and identity refs. A backup procedure without a clean restore observation is not recovery evidence.

### Decision: One bootstrap node is a prerequisite, not availability completion

**Choice:** The bootstrap receipt states that exactly the selected initial node was observed. It cannot satisfy the later independent-seed count, single-seed-outage, cross-failure-domain, or production-readiness gates.

**Rationale:** The first node unblocks publication and integration. Treating it as highly available would erase the main acceptance condition of the wider pilot.

## Evidence Shape

The deterministic bootstrap receipt records the policy identity, package source/version identity, selected machine `aspen1`, its declared failure-domain label, deployment target identity, pinned key fingerprint, node ID, admitted repository IDs, listener and HTTPS endpoint identities, forbidden-authority assertions, service/restart observations, exact probe Git object, off-host backup manifest identity, restore comparison, monitoring result, and explicit non-claims. Onix-owned receipt identities use BLAKE3; Git object IDs retain Git's interoperable algorithm.

The receipt excludes private keys, credentials, raw environment values, private repository contents, and unbounded logs. Runtime collection is a thin shell over explicit commands and files; classification and receipt construction operate over bounded observations in a pure deterministic core.

## Positive and Negative Validation

Positive fixtures cover an admitted package assigned to `aspen1`, the `root@aspen1.local` deployment path, persistent state, explicit listeners, public repository allowlisting, HTTPS exact-object acquisition, restart continuity, monitoring, off-host backup verification, and clean restore. Negative fixtures cover an old package, weak signed-reference feature, missing host or failure domain, wildcard exposure without admission, private repository admission, transient storage, writable HTTP behavior, delegate or CI credential injection, unbounded retention, malformed endpoint, incomplete backup, tampered BLAKE3 manifest, changed node/repository identity after restore, and receipt secret leakage.

## Risks / Trade-offs

- A single bootstrap host is an availability bottleneck until the independent second seed is deployed and accepted.
- HTTPS introduces DNS, TLS, proxy, and gateway failure modes distinct from Radicle peer synchronization.
- Aspen1 already hosts privileged services, so unit isolation and negative credential-access checks are acceptance conditions rather than best-effort hardening.
- Persisting node identity improves continuity but increases the importance of state permissions and encrypted off-host backup handling.
- Aspen1's legacy 56 GiB store predates this admission policy; public HTTPS MUST remain disabled until the proxy proves repository allowlisting and non-enumeration over that inherited state.
- A public seed stores and serves admitted source bytes; replication does not prove source correctness, review acceptance, or release eligibility.
- Downstream GitHub independence remains bounded to published Onix-owned repositories and does not remove GitHub-hosted third-party Nix or Cargo inputs.
