## ADDED Requirements

### Requirement: SourceIO trait abstracts filesystem operations
The vendored `nickel-lang-core` SHALL define a `SourceIO` trait with three methods: `current_dir() -> io::Result<PathBuf>`, `read_to_string(&Path) -> io::Result<String>`, and `metadata_timestamp(&Path) -> io::Result<SystemTime>`. The trait MUST be object-safe (usable as `Box<dyn SourceIO>`).

#### Scenario: Trait is defined and object-safe
- **WHEN** the `SourceIO` trait is defined in the vendored `cache.rs`
- **THEN** `Box<dyn SourceIO>` compiles without errors

### Requirement: StdSourceIO preserves existing filesystem behavior
The vendored `nickel-lang-core` SHALL provide a `StdSourceIO` struct implementing `SourceIO` that delegates to `std::env::current_dir()`, `std::fs::read_to_string()`, and `std::fs::metadata().modified()`. This MUST be the default when constructing `SourceCache` without specifying an IO provider.

#### Scenario: Default SourceCache uses StdSourceIO
- **WHEN** `SourceCache::new()` is called without an explicit IO provider
- **THEN** it uses `StdSourceIO` internally, preserving identical behavior to unpatched Nickel

#### Scenario: StdSourceIO delegates to std::fs
- **WHEN** `StdSourceIO::read_to_string("/some/path")` is called
- **THEN** it returns the same result as `std::fs::read_to_string("/some/path")`

### Requirement: SourceCache holds a SourceIO provider
The `SourceCache` struct SHALL have an `io: Box<dyn SourceIO>` field. A constructor or builder method MUST allow injecting a custom `SourceIO` implementation.

#### Scenario: Custom SourceIO is injectable
- **WHEN** `SourceCache` is constructed with a custom `SourceIO` implementation
- **THEN** all subsequent `normalize_path`, `add_normalized_file`, and `timestamp` calls use the custom implementation instead of `std::fs`

### Requirement: normalize_path uses SourceIO::current_dir
The `normalize_path` function (or its equivalent) SHALL call `self.io.current_dir()` instead of `std::env::current_dir()` when resolving relative paths.

#### Scenario: Relative path normalization uses injected IO
- **WHEN** `get_or_add_file("relative/path.ncl")` is called with a custom `SourceIO` whose `current_dir()` returns `/virtual/base`
- **THEN** the path is normalized to `/virtual/base/relative/path.ncl`

### Requirement: add_normalized_file uses SourceIO::read_to_string
The `add_normalized_file` function SHALL call `self.io.read_to_string(&path)` instead of `std::fs::read_to_string(&path)`.

#### Scenario: File content read uses injected IO
- **WHEN** an import triggers `add_normalized_file` with a custom `SourceIO`
- **THEN** the file content comes from the custom `read_to_string` method, not `std::fs`

### Requirement: timestamp uses SourceIO::metadata_timestamp
The `timestamp` function (or calls to `std::fs::metadata().modified()`) SHALL be replaced with `self.io.metadata_timestamp(&path)`.

#### Scenario: Timestamp check uses injected IO
- **WHEN** cache staleness is checked with a custom `SourceIO`
- **THEN** the timestamp comes from the custom `metadata_timestamp` method

### Requirement: Patch is confined to cache.rs
All changes to vendored Nickel source SHALL be confined to `cache.rs` (trait definition, field addition, three callsite replacements, constructor changes). No other source files in `nickel-lang-core` SHALL be modified.

#### Scenario: Diff is localized
- **WHEN** the vendored nickel-lang-core is diffed against upstream 0.17.0
- **THEN** only `cache.rs` has modifications
