## ADDED Requirements

### Requirement: Stdlib prepared once per WASM instance lifetime

The Nickel plugin SHALL prepare the stdlib (parse, compile, transform) at most once per WASM instance lifetime. All subsequent `evalNickel*` calls within the same instance SHALL reuse the prepared stdlib via `CacheHub::clone_for_eval()`.

#### Scenario: First call prepares stdlib and caches it
- **WHEN** the first `evalNickelFile` call executes in a fresh WASM instance
- **THEN** the plugin creates a `CacheHub`, calls `prepare_stdlib()`, and stores the result in `thread_local!` storage

#### Scenario: Subsequent calls reuse cached stdlib
- **WHEN** a second or later `evalNickelFile` call executes in the same WASM instance
- **THEN** the plugin clones the cached `CacheHub` via `clone_for_eval()` instead of calling `prepare_stdlib()` again

#### Scenario: Cloned CacheHub has correct IO provider
- **WHEN** the plugin clones the cached `CacheHub` for a call with a specific `base_path`
- **THEN** the cloned `CacheHub`'s `sources.io` field is set to a `WasmHostIO` with the current call's `base_path`, enabling correct import resolution relative to the evaluated file

### Requirement: Cached stdlib produces identical results

All `evalNickel*` functions SHALL produce identical Nix values whether the stdlib was freshly prepared or cloned from cache.

#### Scenario: evalNickelFile with cached stdlib matches fresh evaluation
- **WHEN** `evalNickelFile` is called on any `.ncl` file using a cloned CacheHub
- **THEN** the returned Nix value is identical to what a fresh `CacheHub` with `prepare_stdlib()` would produce

#### Scenario: evalNickelFileWith with cached stdlib matches fresh evaluation
- **WHEN** `evalNickelFileWith` is called with any `.ncl` file and args using a cloned CacheHub
- **THEN** the returned Nix value is identical to what a fresh `CacheHub` with `prepare_stdlib()` would produce

### Requirement: evalNickel (string input) uses cached stdlib

The `evalNickel` and `evalNickelWith` functions (which take source strings, not file paths) SHALL also use the cached stdlib. Since these functions have no `base_path`, the cloned CacheHub SHALL use a no-op `SourceIO` that returns errors on filesystem operations (string evaluation does not use imports).

#### Scenario: evalNickel reuses cached stdlib
- **WHEN** `evalNickel` is called with a Nickel source string
- **THEN** the plugin uses the cached CacheHub with a no-op SourceIO

#### Scenario: evalNickelWith reuses cached stdlib
- **WHEN** `evalNickelWith` is called with a Nickel source string and args
- **THEN** the plugin uses the cached CacheHub with a no-op SourceIO
