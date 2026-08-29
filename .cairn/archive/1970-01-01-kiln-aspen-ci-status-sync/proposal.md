# Proposal: Kiln Aspen CI status sync

## Why

The Radicle CI broker writes job status as `xyz.radworks.job` COBs directly
into the seed node's storage. The broker's own announce step fails on job
updates with `no refs were announced`, so peer nodes do not learn about new
status reliably without operator action. A manual `rad sync` for the
repository makes the owner node fetch the announced refs, which was verified
to propagate job `235f50cb19802b8a8c9f316ed42d21a8415d754f` and the
successful run job `7b45072ccfd03a4c15318205fb7a0bde7ddb4724`.

Leaving propagation manual means CI status silently stops reaching peers
whenever an operator forgets the sync step.

## What changes

- Add a `kiln-aspen-ci-status-sync.path` unit that watches the bot
  namespace signed-refs file in the admitted repository storage and fires
  after each CI status write.
- Add a `kiln-aspen-ci-status-sync.service` oneshot that runs `rad sync`
  for the admitted repository as the `radicle` user with unix-socket-only
  address families, because the CLI talks to the local node control socket
  and the node itself owns all networking.
- Document the announce limitation, the manual remedy, and the operator
  procedure that repairs the Radicle CLI profile after a restore.

## Non-goals

- No change to the broker, its vendored `radicle-job` crate, or its announce
  behavior; that is upstream work.
- No change to CI semantics, admission, reports, or the provider workflow.
- No claim that propagation proves remote CI correctness or release
  eligibility.
