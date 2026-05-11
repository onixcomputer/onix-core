## Phase 1: Cargo policy

- [x] [serial] Write the OpenSpec package for bounded direct Cargo builds and Rust cache storage policy.
- [x] [serial] Add a managed Cargo default jobs limit for `britton-desktop` while preserving the existing rustc-wrapper, target-dir, retry, quiet, and mold settings. ✅ verified generated Cargo config includes `jobs = 20`, managed rustc-wrapper, `/home/brittonr/.cargo-target`, `net.retry = 3`, `term.quiet = false`, and mold rustflags.
- [x] [parallel] Document the hardware rationale and override/resource-scoped workflow for intentionally heavy direct Cargo builds. ✅ documented `build.jobs = 20` rationale and `systemd-run --user --scope` heavy-build override in `inventory/home-profiles/brittonr/sccache/README.md`.
- [x] [parallel] Document or configure the current sccache cache budget and shared target-dir usage inspection workflow. ✅ documented 32 GiB sccache budget, `sccache --show-stats`, and `du -sh /home/brittonr/.cache/sccache /home/brittonr/.cargo-target`; verified generated config sets `size = 34359738368`.

## Phase 2: Verification

- [x] [depends:rustcache.shared-target-compat] Evaluate or inspect the generated Cargo config. ✅ generated Cargo config contains `jobs = 20`, managed rustc-wrapper, `/home/brittonr/.cargo-target`, `net.retry = 3`, `term.quiet = false`, and mold rustflags.
- [x] [depends:rustcache.fail-open] Re-run the sccache fail-open check after Cargo config changes. ✅ invoked generated `cargo-rustc-sccache-wrapper` with `SCCACHE_SERVER_UDS=/tmp/onix-core-broken-sccache.sock` and `rustc --version`; wrapper returned `rustc 1.94.1` successfully.
- [x] [depends:rustcache.storage-policy] Capture cache and target-dir size inspection evidence. ✅ generated sccache config sets `/home/brittonr/.cache/sccache` with 32 GiB budget; current usage snapshot: sccache cache `0`, shared target dir `1.3T`.
- [x] [depends:phase-1] Build the affected Home Manager or host configuration. ✅ `nix build --no-link .#nixosConfigurations.britton-desktop.config.home-manager.users.brittonr.home.activationPackage -L` succeeded.
