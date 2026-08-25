## Phase 1: Package and configuration core

- [x] [serial] Package the immutable Celld release and prove the executable version for r[onix.celld_rustfs.package].
- [x] [serial] Add typed Celld settings and pure positive and negative validation for r[onix.celld_rustfs.validation].
- [x] [serial] Register the Celld Clan module and focused module checks for r[onix.celld_rustfs.composition].

## Phase 2: Storage and service shell

- [x] [serial] Generate shared encrypted Celld credentials and implement idempotent bucket-scoped RustFS provisioning for r[onix.celld_rustfs.storage].
- [x] [serial] Add hardened systemd services, private state, Tailnet listeners, and interface-only firewall policy for r[onix.celld_rustfs.security].
- [x] [serial] Add the deterministic counter Worker deployment for r[onix.celld_rustfs.runtime].

## Phase 3: Composition and static verification

- [x] [serial] Compose one three-node inventory instance with exactly one provisioner for r[onix.celld_rustfs.composition].
- [x] [serial] Run positive and negative settings checks, generated-service checks, package checks, Cairn gates, and all affected system builds for r[onix.celld_rustfs.validation].

## Phase 4: Runtime acceptance

- [ ] [serial] Deploy the bucket, policy, credentials, Worker, and all three Celld services for r[onix.celld_rustfs.storage.provision].
- [ ] [serial] Run Celld storage diagnosis through every RustFS endpoint for r[onix.celld_rustfs.storage.fencing].
- [ ] [serial] Prove cross-node counter continuity and coordinated restart persistence for r[onix.celld_rustfs.runtime].
- [ ] [serial] Prove one-node loss, surviving writes, rejoin, and recovered-node continuity for r[onix.celld_rustfs.failure].

## Phase 5: Completion

- [ ] [serial] Record bounded runtime evidence and non-claims for r[onix.celld_rustfs.runtime].
- [ ] [serial] Sync the accepted specification, archive the change, validate the final tree, and integrate the verified branch for r[onix.celld_rustfs.failure].
