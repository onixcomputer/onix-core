## Phase 1: Shared contracts

- [x] [serial] Add the reusable pure RustFS bucket policy component and positive and negative tests. r[onix.rustfs_build_caches.storage] r[onix.rustfs_build_caches.verification]
- [x] [depends:add-the-reusable-pure-rustfs-bucket-policy-component-and-positive-and-negative-tests] Add typed schemas and pure settings validation for Kache and niks3. r[onix.rustfs_build_caches.storage]
- [x] [depends:add-typed-schemas-and-pure-settings-validation-for-kache-and-niks3] Add Nickel fixtures and generated configuration checks. r[onix.rustfs_build_caches.verification]

## Phase 2: Kache

- [x] [depends:add-nickel-fixtures-and-generated-configuration-checks] Add the Kache RustFS provisioning shell, credentials, daemon, and sync command. r[onix.rustfs_build_caches.kache]
- [x] [depends:add-the-kache-rustfs-provisioning-shell-credentials-daemon-and-sync-command] Point the desktop Home Manager Kache profile at the private remote while preserving the local-only Nix sandbox wrapper. r[onix.rustfs_build_caches.kache.sandbox]

## Phase 3: niks3

- [x] [depends:add-nickel-fixtures-and-generated-configuration-checks] Add pinned upstream niks3 modules, private server composition, signing, and RustFS provisioning on Aspen1. r[onix.rustfs_build_caches.niks3]
- [x] [depends:add-pinned-upstream-niks3-modules-private-server-composition-signing-and-rustfs-provisioning-on-aspen1] Add trusted read-proxy settings and auto-upload roles on Aspen1, Aspen3, and the desktop. r[onix.rustfs_build_caches.uploaders]

## Phase 4: Verification and rollout

- [ ] [depends:point-the-desktop-home-manager-kache-profile-at-the-private-remote-while-preserving-the-local-only-nix-sandbox-wrapper,add-trusted-read-proxy-settings-and-auto-upload-roles-on-aspen1-aspen3-and-the-desktop] Run focused checks, Cairn validation, Clan vars checks, and complete builds for all three nodes. r[onix.rustfs_build_caches.verification]
- [ ] [depends:run-focused-checks-cairn-validation-clan-vars-checks-and-complete-builds-for-all-three-nodes] Deploy the three nodes and capture Kache, niks3, IAM, restart, Tailnet, and negative evidence. r[onix.rustfs_build_caches.kache] r[onix.rustfs_build_caches.niks3]
- [ ] [depends:deploy-the-three-nodes-and-capture-kache-niks3-iam-restart-tailnet-and-negative-evidence] Sync the accepted specification, archive the change, and integrate the verified branch. r[onix.rustfs_build_caches.verification]
