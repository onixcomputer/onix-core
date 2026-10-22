# Design: Accept radicle-node 1.10.3 and radicle-httpd 0.28.0

## Context

`_radicle-node-checks.nix` used one `reviewedNodeVersion` for three roles:
the exact packaged release the check admits, the module minimum quoted by the
old-package negative case, and the version recorded by the accepted bootstrap
receipt. The replica check used the same name for its minimum and its
receipt version. The httpd identity already had separate reviewed and
bootstrap values.

## Decisions

### Decision: Split the node version by role

**Choice:** `reviewedNodeVersion = "1.10.3"` gates the packaged release.
`minimumNodeVersion = "1.9.1"` matches `validate-settings.nix`.
`bootstrapNodeVersion` and `receiptNodeVersion` stay at the 1.9.1 the
accepted receipts recorded.

**Rationale:** Accepting a newer release must not rewrite what historical
receipts recorded or raise the module minimum. Separate names keep each
comparison true to its source.

### Decision: Replace the reviewed httpd identity in place

**Choice:** Update the reviewed httpd version, tag, and hashes to 0.28.0 and
keep `bootstrapHttpdVersion` at 0.25.0.

**Rationale:** The check already separates the reviewed identity from the
bootstrap receipt, so only the reviewed values change.

## Risks / Trade-offs

- The next `radicle-node` or `radicle-httpd` bump fails
  `radicle-node-policy` again until an operator accepts it, which is the
  intended gate.
