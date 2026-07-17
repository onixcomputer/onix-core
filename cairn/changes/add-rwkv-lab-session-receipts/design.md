# Design: Device-free RWKV lab session receipts

## Goal and Success Contract

Produce a reusable device-free boundary that turns an exported typed manifest into a deterministic plan receipt and classifies saved evidence without executing the planned command. Completion requires:

- a Nickel contract that rejects missing or ill-typed session fields;
- a pure Rust core that validates semantic invariants and derives a BLAKE3 plan identifier from normalized data;
- deterministic classification of positive, negative, partial, blocked, and unsafe evidence fixtures;
- a thin CLI shell limited to reading JSON and writing receipts;
- package checks proving the CLI contains no process-spawn or hardware-orchestration path; and
- no Tenstorrent enumeration, owner mutation, runtime initialization, or physical-process count change.

A syntactically valid manifest without semantic validation, a classifier that accepts a mismatched plan identifier, a zero-status process promoted without required success evidence, a restoration failure reported as ordinary failure, any manifest-command execution path, or any physical validation is false completion.

## Functional Core and Imperative Shell

`pkgs/rwkv-lab/src/lib.rs` is the functional core. It receives deserialized values and returns validated plans, plan receipts, or classification receipts. It performs no filesystem, environment, clock, network, or process I/O.

`pkgs/rwkv-lab/src/main.rs` is the imperative shell. It accepts only `check`, `plan-id`, and `classify`; reads exported JSON files; calls the core; and writes deterministic JSON or a plan identifier to standard output. It has no executor, subprocess, service-control, device-selection, or runtime-preparation mode.

Nickel remains the authoring and type-checking format. The CLI intentionally consumes exported JSON so an arbitrary manifest cannot cause the classifier itself to evaluate imports or spawn another program. Package tests export the checked-in positive and negative Nickel fixtures before invoking the CLI.

## Manifest Boundary

A session manifest binds:

- schema version, stable session ID, and integration-ladder stage;
- exact package, kernel, executable, immutable argument vector, architecture, physical device, and device path;
- exact owner unit and owner-control helper;
- absolute cache, log, and run roots plus loopback Inspector address;
- one process, timeout, timeout status, kill grace, rollback delay, and expected health status;
- required artifact roles and exact success markers; and
- one narrow success claim plus explicit non-claims.

Semantic validation requires immutable executables and package paths under `/nix/store`, runtime state outside `/nix/store`, exact device-path consistency, a single-process budget, rollback later than timeout plus kill grace, sorted unique evidence expectations, and non-empty non-claims.

## Classification Boundary

Evidence is bound to the BLAKE3 plan identifier and records process, owner-isolation, and restoration counts; an optional terminal process result; owner and board recovery observations; artifact role/digest/size records; and observed markers.

Classification precedence is safety-first:

1. Counter, ordering, timeout, restoration, or board-health contradictions produce `unsafe`.
2. Zero process attempts with no isolation produce `not_run`.
3. Zero process attempts after safely restored isolation produce `blocked`.
4. One process with missing required artifact roles produces `partial_diagnostic`.
5. One zero-status non-timeout process with all required artifacts and markers produces `passed`.
6. Other complete terminal process results produce `failed`.

Only `passed` carries the manifest's narrow success claim. Every outcome retains explicit non-claims. A process attempt always exhausts the one-process budget, independent of status.

## Portfolio Search

| Family | Mechanism | State | Evidence or blocker |
|---|---|---|---|
| Typed receipt core | Nickel authoring plus pure Rust normalization, BLAKE3 binding, and classification | selected | Reuses repository Rust packaging and makes positive/negative fixtures deterministic without an executor. |
| Generated Bash runbook | Render another executable one-shot script from a manifest | rejected for this slice | Reintroduces a hardware-capable execution surface before fresh authorization and leaves classification coupled to shell text. |
| Manual runbook cloning | Continue copying archived scripts and source checkers | falsified | The existing archives demonstrate large duplicated metadata and classification logic; this is the drift being removed. |
| Cairn probe execution | Encode each lab process as a Cairn probe | blocked | Probe receipts are lifecycle evidence, but command execution would violate this slice's no-executor boundary and does not replace domain classification. |

The local secondary reviewer was unavailable (`fetch failed`), so the selected mechanism receives deterministic adversarial tests rather than model agreement.

## Adversarial Audit

- A manifest command is data only; the binary has no call to `std::process::Command`.
- A plan-ID mismatch is rejected before classification.
- Duplicate roles, markers, claims, and evidence records fail rather than being silently deduplicated.
- Status zero cannot pass without every exact success marker and required artifact role.
- A timeout must carry the configured timeout status.
- Any process requires exactly one prior isolation and exactly one restoration attempt.
- Failed owner health or board health outranks ordinary failure and becomes `unsafe`.
- The tool does not infer physical correctness from package checks or synthetic fixtures.

## Budgets and Stop Conditions

Primary authority is the accepted Tenstorrent runtime specification, archived one-shot boundaries, and current repository package conventions. Retrieval is limited to those local sources. Validation is limited to Nickel export, Rust tests, Nix package/install checks, formatting, Cairn gates, and clean-worktree Cairn validation. Hardware access and owner mutation are excluded.

The slice terminates as `validated` when all device-free checks pass, `blocked` on an exact unavailable tool or repository invariant, or `exhausted` if the bounded tests cannot discriminate the classifier outcomes. Physical correctness is not an allowed result.

## Validation Evidence

The typed positive manifest exports successfully, the type-negative manifest fails Nickel evaluation, and the semantic-negative manifest exports but fails Rust validation. Nine Rust unit tests cover deterministic planning plus positive and negative classification; `cargo fmt`, Clippy with warnings denied, and the complete Rust test suite pass. Nix package and install checks pass at `/nix/store/28kaci6hqqpjvfskf1f5z70kwfhjzxv9-rwkv-lab-0.1.0`, including `passed`, `partial_diagnostic`, and `unsafe` CLI fixtures, mismatched-plan and device-node input rejection, and source inspection that rejects process or hardware orchestration primitives. The existing ttWKV7 package remains unchanged at `/nix/store/9ci0570g2yh2cc5m8li1qw8bq4gp0fa4-ttwkv7-unstable-2026-06-22`. Focused `deadnix`, `statix`, and `treefmt` checks pass. Clean detached-worktree Cairn validation and proposal, design, and tasks gates report `valid: true` with no issues. No Tenstorrent device, owner service, Metalium runtime, or physical-process counter was accessed.
