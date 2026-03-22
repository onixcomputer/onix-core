## Context

The project runs a fork of Nix (2.33.3) with `builtins.wasm` (cherry-picked NixOS/nix#15380). A Rust workspace at `wasm-plugins/` produces `.wasm` binaries consumed by `lib/wasm.nix` wrappers. The existing plugins (YAML, INI) follow a pattern: Rust crate depends on `nix-wasm-rust` for the Value FFI, compiles to `wasm32-unknown-unknown`, gets optimized by `wasm-opt`, and is called via `builtins.wasm { path = ...; function = "name"; } arg`.

Nickel's evaluator (`nickel-lang-core`, ~48K lines Rust) already compiles to `wasm32-unknown-unknown` — the upstream `nickel-wasm-repl` crate proves this. That crate uses `wasm-bindgen` for JS interop, which is incompatible with the `builtins.wasm` ABI. The goal is to bridge Nickel's evaluator to the Nix WASM host using the same `nix-wasm-rust` FFI that the YAML/INI plugins use.

The existing Nix↔Nickel bridge (organist/nickel-nix) works via IFD: `nickel export` runs in a `runCommand` derivation, writes JSON, and Nix reads it back with `builtins.fromJSON`. This is slow, uncacheable during eval, and disallowed by many CI systems.

## Goals / Non-Goals

**Goals:**
- Evaluate Nickel source strings within Nix evaluation, returning native Nix values (attrsets, lists, strings, numbers, bools, null).
- Evaluate `.ncl` files from Nix store paths using the host `read_file`/`make_path` ABI.
- Support Nickel's `import "relative.ncl"` syntax by resolving paths against the source tree via the host ABI.
- Expose clean Nix wrapper functions (`wasm.evalNickel`, `wasm.evalNickelFile`) consistent with the existing `wasm.fromYAML`/`wasm.fromINI` pattern.
- Full test coverage via `_wasm-checks.nix`.

**Non-Goals:**
- Passing Nix values INTO Nickel as typed inputs (merging Nix attrsets with Nickel contracts). This is a future phase.
- Replacing Nix modules with Nickel modules. Nickel configs supplement Nix, they don't replace the module system.
- Supporting Nickel's package/lock file system (`nickel.lock.ncl`). Initial implementation handles self-contained `.ncl` files and relative imports only.
- Optimizing cold-start time. The WASM instance is fresh per call by design (determinism guarantee). Stdlib re-parsing is accepted overhead.
- Providing a Nickel REPL or interactive features. Eval-only.

## Decisions

### 1. Embed nickel-lang-core, not the CLI

**Decision**: Depend on `nickel-lang-core` as a Rust library with `default-features = false`, stripping `repl`, `repl-wasm`, `markdown`, `doc`, and `format` features.

**Rationale**: The CLI and REPL pull in rustyline, termimad, comrak, topiary, tree-sitter — none of which compile to WASM or serve the eval-only use case. The `nickel-lang-core` library with default features disabled gives us: parser, evaluator, typechecker, stdlib, and serialization (JSON/YAML/TOML). These are the only pieces needed.

**Alternative**: Shell out to `nickel export` at Nix eval time. Rejected — this is what organist does via IFD, and it's the thing we're trying to eliminate.

### 2. JSON round-trip for Nickel→Nix value conversion

**Decision**: Evaluate Nickel to a `NickelValue`, serialize to JSON via `nickel_lang_core::serialize::to_string(ExportFormat::Json, &value)`, parse JSON with `serde_json`, then convert the `serde_json::Value` tree to Nix `Value` objects using the `nix-wasm-rust` FFI.

**Rationale**: Nickel's internal value representation (`NickelValue`) is deeply intertwined with the evaluator's closure/thunk machinery. Direct traversal would require coupling tightly to Nickel internals. JSON is Nickel's canonical export format, serialization is well-tested, and `serde_json` adds negligible binary size. The round-trip cost is small compared to evaluation itself.

**Alternative**: Walk Nickel's AST/value tree directly and call `Value::make_*` for each node. Rejected — too fragile across Nickel version upgrades, and `NickelValue` isn't designed for external consumption.

### 3. Host ABI for file reading (Phase 2)

**Decision**: For `evalNickelFile`, use `Value::read_file()` to read the `.ncl` source from a Nix path, then feed the content as a string to Nickel's evaluator. For Nickel `import` resolution, implement a custom source provider that maps relative paths through the host's `Value::make_path(base, rel)` + `Value::read_file()`.

**Rationale**: The `builtins.wasm` ABI provides `read_file` and `make_path` specifically for this purpose — the grep plugin demonstrates the pattern. This avoids any filesystem access from within WASM (which isn't available on `wasm32-unknown-unknown`) and keeps all path resolution under Nix's control for reproducibility.

**Alternative**: Require all Nickel source to be inlined as strings. Rejected — defeats the purpose of `.ncl` files and makes multi-file Nickel projects impossible.

### 4. Two-phase delivery

**Decision**: Phase 1 delivers `evalNickel` (string input only). Phase 2 adds `evalNickelFile` with import resolution. Both functions ship in the same `nickel-plugin` crate; Phase 2 is additive.

**Rationale**: String evaluation has zero filesystem dependencies and can be validated immediately. File-based evaluation requires implementing a custom import resolver against Nickel's cache/import internals, which is a larger surface area. Shipping Phase 1 first gets the core capability working and tested.

### 5. Pin Nickel version in Cargo.toml

**Decision**: Pin `nickel-lang-core` to a specific git rev or crates.io version. Don't track `main`.

**Rationale**: Nickel's internal APIs change between releases. The `Program` API, `CacheHub`, and `EvalCache` trait have shifted across versions. A pinned version lets us test against a known interface and upgrade deliberately.

## Risks / Trade-offs

**[WASM binary size ~2-5MB]** → Accept. The existing YAML plugin is ~185KB, QuickJS is ~586KB. Nickel with stdlib will be larger. Mitigated by `wasm-opt -Oz`, LTO, `opt-level = "z"`, and feature stripping. Binary is built once and cached in the Nix store.

**[Cold-start per evaluation ~50-200ms]** → Accept as architectural constraint. `builtins.wasm` guarantees determinism by creating a fresh WASM instance per call. Nickel's stdlib (~6K lines) is re-parsed each time. Users should structure Nix code to minimize the number of `evalNickel` calls (evaluate one large config, not many small fragments).

**[Nickel import resolution in WASM]** → The `cache.rs` module uses `std::fs` for file reads. On `wasm32-unknown-unknown`, `std::fs` operations panic. Phase 2 requires either: (a) patching Nickel's import resolver to use an injected I/O trait, or (b) pre-loading all imported files and feeding them as virtual sources via `CacheHub::add_string`. Option (b) is simpler but requires knowing the import graph upfront. Phase 1 sidesteps this entirely.

**[Nickel version coupling]** → The `Program` API is public but not stability-guaranteed. Pin and test. Upgrade path: bump version, fix any API drift, re-run checks.

**[std::fs panic on wasm32-unknown-unknown]** → Phase 1 avoids all file operations by taking string input. Phase 2 must intercept file reads before they reach `std::fs`. Nickel's `CacheHub` supports adding sources as strings — the strategy is to read files via the host ABI and inject them into the cache before evaluation triggers imports.
