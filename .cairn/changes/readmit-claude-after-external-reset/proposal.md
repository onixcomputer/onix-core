## Why

Underclass kept both Claude subscriptions in `cooling` after their usage API
changed: one now has weekly headroom, but its persisted upstream reset deadline
remained in the future. A successful direct Anthropic request did not change
Underclass's pool state, so OMP requests on Britton, Aspen3 and the Mac all
received a pool-level 429 before any Claude account was selected.

## What Changes

- Pin the Underclass fork revision that reconciles stale Claude cooldowns with
  fresh, valid quota-window usage; keep exhausted or unknown accounts cooling.
- Publish the already deployed dynamic Codex/OpenCode Go provider in onix-core
  and add Claude Messages catalog and request shaping to that same provider.
- Deploy the pinned service on Britton without changing its listener, state,
  account credentials, SSH tunnels, or reset-credit settings.
- Exercise paid Claude via the real OMP provider from Britton, Aspen3 and the
  Mac, and attribute selection to the account with observed headroom.

## Impact

The existing single pool and its callers remain in place. The usage poll can
readmit an externally reset account without user login or consuming a banked
reset credit. The managed OMP provider exposes that account without regressing
the Codex and OpenCode Go routes. Other account records remain unchanged.

## Affected Specs

- `underclass-claude-readmission`: fail-closed usage reconciliation, managed
  provider request shape, and source-bound, scoped deployment.
