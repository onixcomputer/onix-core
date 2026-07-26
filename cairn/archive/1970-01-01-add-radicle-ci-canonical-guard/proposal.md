# Add a guarded Radicle CI canonical compare-and-swap

## Why

The Bounded Exec pilot publishes bounded CI observations but no checked onix-core mechanism currently combines the signed bot status, exact patch revision, delegate approvals, threshold delegate namespace signed refs, current canonical predecessor, Git ancestry, and a Valence admission receipt before a canonical ref update. Operators must not substitute a successful result file or human comment for this complete authorization input.

## What Changes

- Publish a closed machine-readable CI status payload inside the bot's signed Radicle patch comment while preserving the existing human non-claim.
- Add a pure deterministic guard core that validates the accepted CI policy, typed event/result, status payload, Valence admission receipt, exact live patch/revision facts, threshold delegate approvals, threshold `parent` signed refs naming the candidate, canonical predecessor, and descendant candidate.
- Add a preview-first operator shell that loads one explicit Radicle storage repository and performs an atomic `refs/heads/main` compare-and-swap only with `--execute` after every check passes.
- Retain typed Nickel guard policy, positive/negative fixtures, package checks, and lifecycle evidence.
- Keep the deployed CI bot and credentialless runner unable to read or mutate production storage; do not add an automatic guard service or widen CI beyond Bounded Exec.

## Impact

This adds a bounded operator capability to the existing `radicle-ci-runner` package and extends its signed status format. It does not grant canonical authority to the bot, runner, seeds, or Valence; does not enforce CI in the Radicle protocol; and does not deploy or execute a production canonical update as part of this change.
