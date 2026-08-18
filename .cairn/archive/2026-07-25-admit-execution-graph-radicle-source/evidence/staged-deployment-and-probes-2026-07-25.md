# Staged execution-graph deployment and probes

Observed: 2026-07-25

## Bound source

- RID: `rad:z2oYsb9jGTyp68BKYhzpivY1eK58a`
- Reviewed commit: `03736f1ec46c377ff86b451260ad68aa70ff3b0b`
- Source archive BLAKE3: `4b5aa3756369236fc82fbbf501d35993cfa208f142694cdd30ca370d6241192c`
- Producer governance: one observed delegate and threshold one
- Target governance: three delegates and threshold two

## Runtime stage

Aspen and the desktop replica run reboot-limited hardened policy timers. Each timer reconciles the three existing live RIDs plus execution-graph.

The normal policy timers are inactive during the stage. Aspen Nginx uses a tested runtime configuration with exact execution-graph upload-pack routes.

All stage units and the Nginx override live under `/run`. They are not durable deployment evidence.

A reboot restores the pre-stage policy and removes the staged HTTPS route.

## Exact acquisition

Fresh ephemeral Radicle profiles used separate state roots, isolated SSH agents, and the `parent` signed-reference feature.

Both stack seeds returned the reviewed commit and expected archive digest:

- Aspen: `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8@100.100.103.95:8776`
- Desktop: `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG@100.110.43.11:8776`

A fresh HTTPS Git clone from `https://git.onix.computer/z2oYsb9jGTyp68BKYhzpivY1eK58a.git` returned the same commit and digest.

## Rejection probes

- valid upload-pack discovery: HTTP 200;
- endpoint root: HTTP 404;
- undeclared RID: HTTP 404;
- receive-pack route: HTTP 404;
- wrong discovery service: HTTP 404;
- missing Git object: rejected.

## Controlled outage observations

The desktop node was stopped while a fresh client cloned only from Aspen. The exact commit and digest matched.

Aspen was stopped while a fresh client cloned only from the desktop. The exact commit and digest matched.

Cleanup traps restarted both services. Both nodes and staged policy timers were active after the drills.

## Portable policy

Revision `156a138828bbc9bca1317755c81c29c08174a06d` adds the public RID to the shared primary, HTTPS, and replica source list. Focused node, replica, and source-admission checks passed.

The branch is local and is not deployed. The live stage preserves a separately managed private RID that is absent from the public source repository.

## Blockers and non-claims

Producer delegate quorum is incomplete. OnixOS catalog revision `8e0af634998c34e171b2e9771e7a496a9df98186` remains pending.

This evidence does not prove durable deployment, canonical publication, accepted governance, consumer cutover, graph correctness, release readiness, or whole-stack GitHub independence.
