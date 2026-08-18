# Live adapter drill evidence — 2026-08-18

This file records the first live execution of the Kiln Radicle adapter
against the real private Seaglass repository.

## Facts

| Fact | Value |
|---|---|
| Repository RID | `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk` |
| Revision | `bea681be760e76a7e18a663df6ed38c2a9d0e1c6` |
| Branch | `master` |
| Check target | `.#checks.x86_64-linux.component-purity` |
| Adapter protocol | `defelo` |
| Source storage | `/home/brittonr/.radicle/storage` (personal node) |
| Run identity | `kiln-bea681be-1787022942630833271` |
| Result | `success` |

## Observed adapter output

```text
{"response":"triggered","run_id":{"id":"kiln-bea681be-1787022942630833271"},"info_url":"https://ci.onix.computer/reports/z3xXXCQXCTquvAawh41YYs8yC8xmk/kiln-bea681be-1787022942630833271.log"}
{"response":"finished","result":"success"}
```

The process exited zero after emitting both lines. The exit code does not
carry the result. The result rides in the terminal `finished` line, which
matches the reference Nix adapter contract.

## Report written by the adapter

The adapter wrote two files under the report directory:

- `<run>.json` with schema `onix.radicle-ci-report.v1`
- `<run>.log` with the bounded command output

The JSON report binds the repository, exact revision, branch, run
identity, and terminal result.

## Interpretation

The drill proves the three-phases flow on the real repository:

1. The adapter parsed the broker request and bound one run identity.
2. The adapter acquired the exact pushed revision from local Radicle
   storage through `git+file://` and executed the admitted flake check
   with Nix.
3. The adapter reported the real terminal outcome and wrote the report.

The early drill history is part of the evidence:

- The first version of the command construction emitted `nix build
  <flake> <attr>` as two installables, so Nix resolved the attribute
  against the working-directory flake and reported `failure`.
- The adapter now emits one installable of the form
  `<flake>#<attr>` and normalizes a leading `.#` in the target.
- The `component-purity` check then built successfully and copied back
  from the remote builder.

## Non-claims

The drill used the personal node storage, not the managed
`/var/lib/radicle` node that the broker will use in deployment. It ran
one check, not the full Seaglass check set. It did not exercise the
Radicle CI broker service or the Radicle job status path.
