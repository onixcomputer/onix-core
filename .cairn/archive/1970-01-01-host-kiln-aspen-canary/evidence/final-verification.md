# Final verification

Date: 2026-08-28

## Verdict

PASS for the exact private, local, process-scoped Kiln-on-Aspen canary.

This verdict does not establish production availability, active-operation durability, CI correctness, workflow correctness, host sandboxing, external effect truth, or release eligibility.

## Deployed identity

- Onix Core commit: `201aa202c1c527ec1beed267775d58b2c761ebea`
- System closure: `/nix/store/gw5ydwxnrhc4fzwyayj2fk68q3hv4qz6-nixos-system-britton-desktop-26.11.20260819.afe3d8a`
- Kiln host: `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`
- Kiln hosted protocol: `42eabcb21385a436ddc044fb7034b8cdaec7b8a0`
- Aspen materialized completion: `22f8ded26ca1907c29948e08b53f35df23080733`
- Lattice application: `c513d94d89e901ffa56ae67f375f973e55958e42`
- Lattice contract: `70496e67c7fd4a8b05914161a8e09de2759bebc8`

## Local gates

| Gate | Result |
|---|---|
| Focused Nix and Nickel formatting | PASS |
| Typed profile exports and negative fixtures | PASS |
| Unoverridden module and package check | PASS |
| Full `britton-desktop` machine evaluation | PASS |
| Strict Cairn validation with generated policy | PASS |

The module check binds the final Kiln input revision, internal protocol revision, no-fallback commands, separate authority, provider budget, and both stale-socket guards.

## Live receipts

| Drill | Result | BLAKE3 |
|---|---|---|
| Aspen accepted | `success` with exact replay | `884a5f1f9c49392bf839fe7fb7e28888c808cfd2706e05bb5ad56f4c9d45fe77` |
| Aspen rejected | `denied` with exact replay | `301ae4db3c79729497aa0269d6b298bcbc180388b227d847cd8be3a9f7b38dbf` |
| Aspen unavailable | `unavailable`, fallback `none` | `495d901c518912c2c30d548904a83edee4dc35e12acc4e04a5902818196d3276` |
| Provider disconnect | `unknown_after_write`, replay `unknown`, fallback `none` | `231eacd656e9d62c25e47d90a655c8c34413873aa0d831fa0d8aeb0c3b855435` |
| Explicit Lattice rollback | `success` with exact replay | `915f619070a0bd2878fd9269a03b828c6676f0a34c1bceb66d49046e8296e9cd` |

The exact bytes are under `evidence/live-receipts/`. `live-canary.json` binds them to the deployed cohort and service facts.

## Restart and recovery

- Both long-lived process identities changed during a controlled restart.
- Each stale Unix socket was removed only by its owning service guard.
- A regular file at either socket path caused the matching service to fail closed.
- Both services restarted after the negative path fixtures were removed.
- The accepted receipt remained byte-for-byte exact after restart.
- The direct Lattice receipt reconciled from `timed_out` to `success` after the bounded poll budget increased.
- The disconnect-after-write receipt remained exact within one host process without provider redispatch.

These facts do not prove durable recovery of Aspen's process-local uncertain-operation set.

## Authority and separation

- The host and Lattice services use separate users, UIDs, and mode-`0700` state roots.
- The runtime directory is mode `0770`; both sockets are mode `0660` with separate owners.
- The uncertainty drill runs as the host user, not root.
- The operator units have no `wantedBy` target.
- The existing Seaglass broker still targets only its reviewed repository and does not select Aspen.
- No automatic runtime fallback was observed.

## Host warnings outside this change

Clan made the final closure current and both canary services remained active. Existing activation snippets still reported the `datapool/kache-nix` quota and `/var/cache/kache-nix` disk quota problems.

Those host storage warnings are not resolved or hidden by this canary verdict.
