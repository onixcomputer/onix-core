## Baseline

Britton's generation 883 runs the fork at `773c236d` with the Underclass
service bound to `127.0.0.1:8080`. Both Claude accounts were cooling despite a
fresh usage snapshot showing 61% seven-day utilization for
`claude@robitzs.ch`; `britton@cproof.ai` remained at 100%. The upstream
`ghuntley/underclass` main branch has no later cooldown fix.

## Decisions

Advance only the `underclass` node in the fleet flake lock to the reviewed,
tested fork commit `ba72139a`. Leave the flake input URL and all other locked
revisions unchanged. The implementation retains cooling when quota is
exhausted, missing or invalid, and only extends rather than shortening a
future exhausted-window deadline. No OAuth login, reset redemption or
credential migration is part of this change.

Deploy through the generation-managed Underclass unit, not a persistent
systemd override. Generation 883's source is not presently rooted at
`~/.local/state/onix-core/deployments/883/source`; check retained source
cohorts or compare a candidate generation's closure and dry-activation against
the live one before switching. Refuse a build that would roll back unrelated
services. The service has a dynamic user and persistent StateDirectory; a
scoped restart preserves the SQLite pool and proxy key.

## Verification

Require the Underclass fork's full offline Rust suite, format and contract
format checks, plus a Nix build from the immutable published revision. Check
that the lock changes only the Underclass node. Before switching, compare
system/unit closures and dry-activation; after switching, confirm that only
the intended account is readmitted, that no reset credit was redeemed, and
that a Claude answer is returned through OMP from each of the three hosts.
