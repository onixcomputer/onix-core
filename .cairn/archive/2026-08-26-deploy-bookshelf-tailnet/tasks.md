## Phase 1: Package and contract

- [x] [serial] Pin and package Bookshelf with its Node application, sync command, license, and install checks. r[onix.bookshelf.package]
- [x] [depends:pin-and-package-bookshelf-with-its-node-application-sync-command-license-and-install-checks] Add the typed Bookshelf service schema and pure settings validation. r[onix.bookshelf.storage] r[onix.bookshelf.network]
- [x] [depends:add-the-typed-bookshelf-service-schema-and-pure-settings-validation] Add positive and negative Nickel and Nix verification fixtures. r[onix.bookshelf.verification]

## Phase 2: Runtime composition

- [x] [depends:add-positive-and-negative-nickel-and-nix-verification-fixtures] Add the hardened systemd service, private datapool paths, Tailnet firewall rule, and explicit publishing command. r[onix.bookshelf.runtime] r[onix.bookshelf.publish]
- [x] [depends:add-the-hardened-systemd-service-private-datapool-paths-tailnet-firewall-rule-and-explicit-publishing-command] Compose the service on `britton-desktop` and document the source, endpoint, publishing procedure, and backup boundary. r[onix.bookshelf.network] r[onix.bookshelf.publish]

## Phase 3: Verification and rollout

- [x] [depends:compose-the-service-on-britton-desktop-and-document-the-source-endpoint-publishing-procedure-and-backup-boundary] Run package, module, contract, Cairn, Clan, and full desktop build checks. r[onix.bookshelf.verification]
- [x] [depends:run-package-module-contract-cairn-clan-and-full-desktop-build-checks] Deploy to `britton-desktop` and record service, firewall, permission, HTTP, and negative exposure evidence. r[onix.bookshelf.storage] r[onix.bookshelf.network] r[onix.bookshelf.runtime]
- [x] [depends:deploy-to-britton-desktop-and-record-service-firewall-permission-http-and-negative-exposure-evidence] Sync accepted specifications, archive the change, and integrate the verified branch. r[onix.bookshelf.verification]
