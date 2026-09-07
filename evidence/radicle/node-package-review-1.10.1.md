# Radicle node package review

## Decision

Keep the selected Radicle 1.10.1 package. Do not downgrade the live node to satisfy the historical bootstrap receipt.
The minimum supported protocol version and the bootstrap receipt remain at 1.9.1.
The infrastructure maintainer owns this package gate.

The existing locked package definition is `pkgs/by-name/ra/radicle-node/package.nix` in source `5jyicr39gf79ybcv7bjwlaiqk7h2fhxz-source`.
This change does not alter the package, flake inputs, host service values, or credentials.

## Reviewed identity

- Repository: `https://seed.radicle.dev/z3gqcJUoA1n9HaHKufZs5FCSGazv5.git`
- Release reference: `refs/tags/releases/1.10.1`
- Commit: `71f39fb195068d598d75f7cd606d41a4f8ad4b10`
- Source hash: `sha256-F+64o9z/al0iaLFyQHAYk/3jjf5T0FdgqaU3nEWIheg=`
- Cargo hash: `sha256-TLffetbkVwIbUDoI+96T99+lfYu2SIpGtwC0DbuJXnU=`

Nix requires these SHA-256 fixed-output identities. They do not replace stack-owned BLAKE3 identities.
The gate checks the whole identity record, the source commit marker, and the executable version.
Each identity field has a negative mutation. A matching version alone cannot admit different source or dependencies.

## Source and runtime observations

The fetched release `CHANGELOG.md` reports stricter signature verification and fixes for private repository identifier leakage and ephemeral keys in 1.10.1.
Version 1.10.0 changes repository identity evaluation. Its changelog also names an unresolved ordering inconsistency between concurrent redact and accept operations.
This review does not claim that Radicle solves that inconsistency. Existing repositories need separate identity observations before deployment acceptance.

A read-only Aspen1 probe on 2026-09-07 reported this exact release and commit from `rad --version`.
The node service already uses `radicle-node-1.10.1`. This gate repair does not authorize an upgrade, cache rewrite, or identity migration.

The upstream package skips several tests. Its package build is not evidence that every upstream test passes.
The repository-owned node-policy check retains the existing positive and negative policy, source-scope, credential, backup, and HTTPS checks.
A passing result applies only to those declared checks. Native Campaign acquisition and deployment evidence remain required.
