## Phase 1: Spike the Nix builder contract

- [x] [serial] Build a minimal sandbox probe that records the Cargo-wrapper and wrapped-rust rustc argv with and without kache enabled. r[onix.nix_rust_cache.wrapper]
- [x] [serial] Verify wrapper behavior in a Nix sandbox with a temporary writable cache dir and no user daemon dependency. r[onix.nix_rust_cache.sandbox]
- [x] [serial] Record that the first slice needs only `KACHE_CACHE_DIR`, `KACHE_LOCAL_ONLY`, wrapper tracing, and explicit disabled mode; no user daemon socket is required by the checked wrapper path. r[onix.nix_rust_cache.validation]

## Phase 2: Add opt-in Nix integration

- [x] [serial] Add Nix-owned kache wrappers that delegate `rustc` through kache and preserve `rustdoc`/toolchain compatibility. r[onix.nix_rust_cache.wrapper]
- [x] [serial] Add typed Nickel-owned settings for enabling the pilot, selecting the cache directory, and configuring any explicit key salt. r[onix.nix_rust_cache.scope]
- [x] [serial] Add NixOS wiring for the machine-owned cache directory and narrow `extra-sandbox-paths` exposure on opted-in hosts. r[onix.nix_rust_cache.sandbox]
- [x] [serial] Salt kache keys with the real rustc, linker, and pilot salt inputs used by the wrapped toolchain. r[onix.nix_rust_cache.key_salt]

## Phase 3: Pilot with changebot/Crane

- [x] [serial] Wire the selected `../changebot` Crane package through a checked example expression that injects the Nix-owned Cargo rustc wrapper. r[onix.nix_rust_cache.changebot]
- [x] [serial] Keep the unwrapped `../changebot` Crane package available as a disabled-pilot fallback. r[onix.nix_rust_cache.rollback]
- [x] [serial] Add positive evidence that the wrapped pilot path invokes kache and records rustc/cache/salt telemetry. r[onix.nix_rust_cache.validation]
- [x] [serial] Add negative evidence that disabling the pilot or omitting sandbox access does not silently use the user Cargo wrapper. r[onix.nix_rust_cache.validation]

## Phase 4: Validate and decide rollout

- [x] [serial] Run Cairn validation and gates for the change package. r[onix.nix_rust_cache.validation]
- [x] [serial] Run focused Nix checks for the wrapper helper, sandbox settings, and selected changebot/Crane pilot example. r[onix.nix_rust_cache.validation]
- [x] [serial] Compare wrapped and unwrapped outputs or derivation behavior for the pilot target and document whether broader rollout is justified. r[onix.nix_rust_cache.validation]
- [x] [serial] Document rollback commands and operational cleanup for the machine-owned cache directory. r[onix.nix_rust_cache.rollback]
