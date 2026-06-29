## Context

The current desktop kache profile manages `~/.cargo/config.toml`, `~/.config/kache/config.toml`, and a user `kache.service`. That is sufficient for interactive Cargo commands, including `nix develop -c cargo ...` when Cargo reads the user's config. It is not visible to sandboxed Nix builders.

A local derivation probe recorded:

- `HOME=/homeless-shelter`
- `initial_CARGO_HOME=<unset>`
- `home_cargo_config=absent`
- `user_cargo_config_absolute=absent`
- `kache_wrapper_seen=no`

`../changebot` uses Crane for its Rust package builds. Crane invokes Cargo inside the Nix builder, so the selected example can opt in through a derivation-owned `RUSTC_WRAPPER` environment variable without relying on `~/.cargo/config.toml`. The helper also exposes a wrapped `rust` package for future `buildRustCrate` consumers that invoke `rustc` directly through the toolchain package.

## Decisions

### 1. Make the Nix kache path opt-in

**Choice:** Add a dedicated pilot setting/helper and require selected packages or workspaces to opt in explicitly.

**Rationale:** A mutable compiler cache inside Nix builders changes failure modes and observability. Opt-in rollout lets us prove behavior on the `../changebot` Crane package before broader use.

### 2. Provide both Cargo-wrapper and wrapped-toolchain helpers

**Choice:** Provide a Nix-owned Cargo `RUSTC_WRAPPER` for Crane-style packages and a Nix derivation whose `bin/rustc` delegates to `${kache}/bin/kache ${realRustc}/bin/rustc "$@"` while preserving `rustdoc` compatibility.

**Rationale:** The selected `../changebot` package is Crane-built and can opt in through derivation environment, while future `buildRustCrate` consumers need a wrapped toolchain package. Both helpers share the same cache-directory checks and key-salt logic.

### 3. Use a machine-owned cache directory

**Choice:** Use a root-managed directory such as `/var/cache/kache-nix`, grant it to Nix builders, and expose exactly that path through `nix.settings.extra-sandbox-paths` for pilot machines.

**Rationale:** The sandbox must not reach into `/home/brittonr/.cache/kache`, and user-level kache state must not become part of Nix build behavior. A machine-owned path makes access explicit and rollbackable.

### 4. Keep the first pilot daemon-independent

**Choice:** Start with local-only kache invocation and do not depend on the user `kache.service`. If upstream kache requires a daemon for reliable operation, promote a separate root/system service only after the spike proves the socket, permissions, and sandbox path contract.

**Rationale:** User daemons are not stable build inputs for Nix derivations. A daemon can be a later optimization, but the first pilot should prove the cache path and wrapper semantics without hidden process dependencies.

### 5. Salt cache keys with Nix toolchain identity

**Choice:** The wrapper must derive `KACHE_KEY_SALT` from the real rustc store path and relevant compiler/linker store paths, and must append any explicit pilot salt.

**Rationale:** Nix builds frequently switch toolchains, targets, and linkers. The cache must not restore artifacts compiled with a different Rust or linker closure.

### 6. Wire the selected example through Crane without editing changebot

**Choice:** Add `examples/kache-nix-rust/changebot-crane-pilot.nix`, a copyable wrapper around `../changebot`'s existing Crane package that injects `RUSTC_WRAPPER` and the machine-owned cache path by derivation override.

**Rationale:** This keeps the pilot outside `../changebot`, avoids patching its flake, and proves the selected example can opt in or fall back by changing only the wrapper expression.

### 7. Verify both positive and negative paths

**Choice:** Add focused checks that prove wrapped builds call kache and fallback builds avoid kache, plus negative checks for missing cache/sandbox access and disabled pilot settings.

**Rationale:** A cache that silently does nothing is not useful, and a cache that fails open in the wrong place can mask reproducibility problems.

## Risks / Trade-offs

- Mutable cache state can improve repeated local builds but must never be required for correctness.
- Adding `extra-sandbox-paths` intentionally pierces the Nix sandbox for one cache path; the path must be narrow and non-secret.
- kache may not cache every Cargo or `buildRustCrate` invocation if argv shape, dep-info, or build-script probes are unsupported; that must be measured rather than assumed.
- Crane already benefits from Nix store caching of dependency artifacts, so the win may be limited to rebuilds where Nix invalidates crate derivations but kache can restore object outputs.