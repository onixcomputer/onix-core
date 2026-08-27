## MODIFIED Requirements

### Requirement: Kache remote artifact cache
r[onix.rustfs_build_caches.kache] Aspen1, Aspen3, and `britton-desktop` MUST run managed Kache Cargo wrappers and credentialed system daemons that synchronize compatible Rust artifacts through the dedicated RustFS bucket.

#### Scenario: Upload Kache artifacts
r[onix.rustfs_build_caches.kache.upload]
- GIVEN a successful interactive Rust build on a configured node
- WHEN the managed Kache wrapper completes compilation
- THEN its node-local daemon MUST synchronize compatible artifacts through the configured RustFS endpoint
- AND another configured node MUST be able to reuse the accepted artifact

#### Scenario: Use bounded node-local storage
r[onix.rustfs_build_caches.kache.storage]
- GIVEN the three nodes have different storage layouts
- WHEN Kache configuration is generated
- THEN every daemon MUST receive an absolute bounded local cache path
- AND Aspen3 MUST place Kache data on its USB4 volume
- AND exactly one node MUST provision shared bucket authority

#### Scenario: Preserve Nix sandbox authority
r[onix.rustfs_build_caches.kache.sandbox]
- GIVEN a Nix derivation uses the Nix-owned Kache wrapper
- WHEN it compiles Rust in a sandbox
- THEN the wrapper MUST remain local-only
- AND the sandbox MUST receive no RustFS credential file

#### Scenario: Remote cache is unavailable
r[onix.rustfs_build_caches.kache.unavailable]
- GIVEN RustFS or a Kache daemon is unavailable
- WHEN Cargo compiles a valid Rust input
- THEN compilation MUST remain able to use the real compiler
- AND cache failure MUST NOT convert a valid compiler result into corrupted output
