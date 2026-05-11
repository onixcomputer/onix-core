## Phase 1: Cargo policy

- [x] [serial] Write the OpenSpec package for bounded direct Cargo builds and Rust cache storage policy.
- [x] [serial] Add a managed Cargo default jobs limit for `britton-desktop` while preserving the existing rustc-wrapper, target-dir, retry, quiet, and mold settings. ✅ verified generated Cargo config includes `jobs = 20`, managed rustc-wrapper, `/home/brittonr/.cargo-target`, `net.retry = 3`, `term.quiet = false`, and mold rustflags.
- [ ] [parallel] Document the hardware rationale and override/resource-scoped workflow for intentionally heavy direct Cargo builds.
- [ ] [parallel] Document or configure the current sccache cache budget and shared target-dir usage inspection workflow.

## Phase 2: Verification

- [ ] [depends:rustcache.shared-target-compat] Evaluate or inspect the generated Cargo config.
- [ ] [depends:rustcache.fail-open] Re-run the sccache fail-open check after Cargo config changes.
- [ ] [depends:rustcache.storage-policy] Capture cache and target-dir size inspection evidence.
- [ ] [depends:phase-1] Build the affected Home Manager or host configuration.
