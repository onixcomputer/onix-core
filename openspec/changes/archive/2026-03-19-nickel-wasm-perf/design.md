## Context

The Nickel WASM plugin (`wasm-plugins/nickel-plugin/src/lib.rs`) evaluates `.ncl` files inside Nix evaluation via `builtins.wasm`. The Nix fork's WASM runtime (wasmtime v40.0.2) caches compiled modules per `SourcePath` using a process-global `InstancePre` with pooling allocator and COW memory init — WASM instantiation is ~10-100µs per call.

The bottleneck is inside the Nickel evaluator. Each call creates a fresh `CacheHub`, which triggers `prepare_stdlib()`:
1. `load_stdlib()` — parses 184KB of Nickel source (std.ncl 165KB + internals.ncl 18KB) through LALRPOP
2. `compile_stdlib()` — lowers ASTs to NickelValue runtime representation
3. `transform()` — import resolution and program transforms per stdlib module
4. `mk_eval_env()` — builds initial evaluation environment from stdlib terms

This runs 69 times during a full fleet eval. The parse/compile guard (`CacheOp::Cached`) only fires within a single `CacheHub` instance — never across calls.

On the Nix side, lack of result sharing between modules causes redundant evaluations: `machines.ncl` 5×, each theme NCL 3× (once per desktop machine), active theme NCL evaluated separately from the theme fold.

## Goals / Non-Goals

**Goals:**
- Eliminate per-call Nickel stdlib initialization overhead (~95% of fixed cost per WASM call)
- Remove redundant Nickel evaluations of identical files across NixOS modules
- Maintain identical evaluation semantics — no behavior change in produced Nix values

**Non-Goals:**
- Optimizing the `nix_to_nickel_source` text serialization (adds <0.4% to parse volume — not worth the complexity)
- Changing the `forceDeep` re-entrancy guard (required for correctness, negligible cost on small args)
- Modifying the Nix fork's WASM runtime (already well-optimized with InstancePre cache + pooling)
- Implementing a batch `evalNickelFiles` API (cached CacheHub provides the same benefit without new API surface)
- Profiling or benchmarking framework (improvements are structural and verifiable by code inspection)

## Decisions

### D1: thread_local CacheHub with pre-prepared stdlib

**Choice**: Use `thread_local!` storage in the Nickel plugin to hold a `CacheHub` where `prepare_stdlib()` has already run. Each call clones via `clone_for_eval()` and swaps `sources.io`.

**Alternatives considered**:
- `static` with `Mutex` — WASM is single-threaded, mutex overhead is pointless. `thread_local!` is zero-cost on wasm32.
- `OnceCell`/`LazyCell` — works but `thread_local! { RefCell }` is more idiomatic for single-threaded WASM since we need mutability during initial preparation.
- Batch API (`evalNickelFiles`) — would achieve the same stdlib amortization but requires new API surface on both Rust and Nix sides. The cached CacheHub approach is invisible to callers.

**Rationale**: `clone_for_eval()` is explicitly designed for this — the Nickel codebase uses it for NLS and benchmarks. It clones `TermCache` (HashMap of `Rc<NickelValue>`, shallow clone for two stdlib entries), `SourceCache` (Files uses `Arc<str>`), and creates a fresh `AstCache` arena. The `io` field on `SourceCache` is `pub`, enabling post-clone swap.

### D2: Skip typechecking via direct VmContext usage

**Choice**: Replace `Program::eval_full_for_export()` with a manual pipeline that calls `prepare_eval_impl` without the typecheck step, then `eval_full_for_export_closure` on the resulting VM.

**Alternatives considered**:
- Keep typechecking — correctness benefit for untrusted input. But our `.ncl` files are in the Nix store (read-only, developer-authored). The Nickel test suite already validates the stdlib types. User source typechecking is pure overhead.
- Compile-time feature flag — adds build complexity for a choice that's always the same (skip) in the WASM plugin context.

**Rationale**: `prepare_stdlib` already skips typechecking with the comment "for performance reasons: this is done in the test suite." Extending this to user source is consistent.

### D3: Evaluate themes once at inventory level, pass via module args

**Choice**: Add an `allThemeData` attrset to the home-manager module args (via `_module.args` or `specialArgs`), evaluated once. `theme.nix` and `theme-data.nix` consume it instead of calling `evalNickelFile` directly.

**Alternatives considered**:
- Evaluate per-machine but share the `let` binding within `theme.nix` — doesn't help, the fold already forces all 5 themes within a single module. The duplication is across machines.
- Lazy evaluation with `lib.mkDefault` — Nix's thunk memoization is per-AST-node, not per-value. Different modules always create separate thunks.

**Rationale**: 15 WASM calls (5 themes × 3 machines) reduced to 5 (one per theme). The theme data is pure (no machine-specific inputs), so evaluating at inventory level is safe.

### D4: Pass machines.ncl result through specialArgs

**Choice**: Evaluate `machines.ncl` once in `core/default.nix` and expose the result via a module arg that `remote-builders.nix` consumes.

**Alternatives considered**:
- Import the `core/default.nix` binding directly — creates a circular import since tags import core and core may import tags.
- Pass through `_module.args` in `wasm-lib.nix` — clean and already the pattern used for the `wasm` arg itself.

**Rationale**: 4 redundant evaluations eliminated. Pattern is consistent with how `wasm` itself is already distributed.

## Risks / Trade-offs

**[Risk] CacheHub clone diverges from upstream Nickel** → The vendored nickel-lang-core is already a patched fork (SourceIO trait). `clone_for_eval` is a stable public API used by NLS. Pin to the current vendor commit and document the dependency.

**[Risk] thread_local state persists stale stdlib across Nix GC cycles** → Not an issue: the WASM instance is destroyed and recreated per `InstancePre` (though the InstancePre itself persists). The `thread_local!` is inside WASM linear memory, which is per-instance. Each WASM instance gets its own thread_local state. However, within a single Nix eval (which reuses the same WASM instance via the InstancePre cache), the stdlib cache persists correctly.

**[Risk] Skipping typechecking masks errors in .ncl files** → Acceptable: errors surface as eval-time failures with clear Nickel error messages. Typechecking is a development-time aid, not a runtime safety net. Developer workflow: run `nickel typecheck` locally on .ncl files.

**[Trade-off] Theme data in module args couples inventory structure to profile structure** → Minor coupling. The theme files are already in the shared profile directory. The evaluation site moves up one level but the data contract is unchanged.

**[Trade-off] `clone_for_eval` drops AST cache** → Not a problem. By the time we clone, the stdlib is already compiled to `TermCache` entries (NickelValue runtime representation). ASTs are only needed for the parse→compile step, which the cache makes redundant. User source still gets its own AST allocation per call.
