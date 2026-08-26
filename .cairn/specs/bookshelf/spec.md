# Bookshelf Tailnet Service Specification

## Purpose

Define a private, declarative Bookshelf deployment for owned EPUB and PDF files on `britton-desktop`.

## Requirements

### Requirement: Immutable package
r[onix.bookshelf.package] The system MUST build Bookshelf from the reviewed immutable upstream revision and MUST preserve its license and notices.

#### Scenario: Build the package
r[onix.bookshelf.package.build]
- GIVEN the pinned source revision and dependency hash
- WHEN Nix builds the Bookshelf package
- THEN the package contains a runnable Node filesystem application
- AND the package contains the operator sync command

#### Scenario: Reject invalid operator input
r[onix.bookshelf.package.reject_invalid]
- GIVEN an unsupported sync option
- WHEN the packaged sync command parses it
- THEN the command fails without changing the published library

### Requirement: Private persistent storage
r[onix.bookshelf.storage] The system MUST keep source books and published library state under an absolute private datapool path owned by the Bookshelf service account.

#### Scenario: Create storage
r[onix.bookshelf.storage.create]
- GIVEN the Bookshelf service is enabled
- WHEN system activation prepares its paths
- THEN the source and library directories use the configured service owner
- AND non-owner access is denied

#### Scenario: Reject unsafe storage settings
r[onix.bookshelf.storage.reject_unsafe]
- GIVEN a relative path, an empty path, or overlapping source and library paths
- WHEN settings are validated
- THEN evaluation fails before activation

### Requirement: Tailnet-only service
r[onix.bookshelf.network] The system MUST bind Bookshelf to its explicit Tailnet address and MUST admit the HTTP port only through the configured private firewall interface.

#### Scenario: Reach the private shelf
r[onix.bookshelf.network.private]
- GIVEN a Tailnet client
- WHEN it requests the configured Bookshelf endpoint
- THEN the application returns an HTTP response

#### Scenario: Inspect generated firewall policy
r[onix.bookshelf.network.no_global_port]
- GIVEN the generated NixOS configuration
- WHEN verification inspects firewall ports
- THEN the Bookshelf port is present on `tailscale0`
- AND the port is absent from global firewall ports

### Requirement: Explicit publishing
r[onix.bookshelf.publish] The system MUST provide an operator command that publishes supported books from the configured source directory into the configured library directory.

#### Scenario: Publish an owned book
r[onix.bookshelf.publish.book]
- GIVEN a valid owned EPUB or PDF in the source directory
- WHEN the operator runs the publishing command
- THEN Bookshelf rebuilds the catalog and generated book assets
- AND the running service serves the updated catalog

#### Scenario: Reject a missing source directory
r[onix.bookshelf.publish.missing_source]
- GIVEN the configured source directory is absent
- WHEN publishing starts
- THEN the command fails with a clear error
- AND it does not claim successful publication

### Requirement: Hardened runtime
r[onix.bookshelf.runtime] The system MUST run Bookshelf as a dedicated unprivileged account with a strict systemd sandbox and bounded restart behavior.

#### Scenario: Start the service
r[onix.bookshelf.runtime.start]
- GIVEN valid settings and prepared storage
- WHEN systemd starts Bookshelf
- THEN the process runs as the dedicated account
- AND only the published library is writable

### Requirement: Verification coverage
r[onix.bookshelf.verification] The system MUST include positive and negative contract fixtures and generated configuration checks.

#### Scenario: Run focused verification
r[onix.bookshelf.verification.run]
- GIVEN the repository verification suite
- WHEN focused Bookshelf checks run
- THEN valid fixtures pass
- AND invalid fixtures report every protected setting field
