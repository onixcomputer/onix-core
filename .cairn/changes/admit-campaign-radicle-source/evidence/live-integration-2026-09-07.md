# Preserve live services before forge deployment

The user approved the live SearXNG/Kagi and Collie integration. The primary checkout remains untouched.

## Source and ownership

- `1386c7a6` adds the selected live service sources. Eleven focused checks and all commit hooks passed.
- The merge preserves committed primary history through `2087998907b208954e0bc8d93ddcc9a719ecd96e`, including existing encrypted Clan variables. It does not generate or rotate secrets.
- Three Noctalia conflicts select the committed live files. These files retain runtime ownership and do not restore retired custom palettes.
- Tree `7871a3bb02a5396677ac373f6fd0300dc533a44e` captures the later Kagi browser repair and its tests. The browser evidence remains historical deployment evidence, not evidence for this candidate.
- The integration excludes unrelated uncommitted Factorseal and DGX work. Onix Core retains service and deployment ownership.
- `flake.lock` remains unchanged by this integration.

## Verification

Frozen tree `d167f30604b6b91efc85a8f0ba8a06aa07f0b231` passes these checks through an explicit `path:` archive:

```text
searxng-module
searxng-kagi-session
module-registry-sync
collie-managed-controller
collie-integration
collie-remote-sessions
herdr-workflow-plugins
hermes-agent-desktop
radicle-node-policy
radicle-campaign-source-scope
radicle-seed-replica
formatter-worktree-root
kiln-aspen-canary-module
kiln-aspen-radicle-ci-module
home-manager-2605-migration
librewolf-search-configuration
```

The Kagi check runs 35 Python tests and four JavaScript tests. All pass. Controls include wrong credentials, cross-session nonces, network errors, timeouts, duplicate submissions, and absent forms.

The imported Kagi baseline failed a raw HTML whitespace assertion. The integration normalizes layout whitespace in both positive and negative assertions. It retains the required message and form attributes. No denial changes or test exclusions apply.

Deadnix, Statix, and treefmt pass. Retained operator logs include `live-integrated-frozen-checks.log`, `kagi-latest-baseline.log`, and `live-latest-hooks.log`.

## Later live UI update

A later live comparison found the new locked-engine row in Aspen1. The earlier candidate did not contain that row, so deployment did not proceed.

Tree `b29f965e139a3ff20642f3606addaed972688766` captures that source update. It also replaces raw HTML assertions with DOM assertions. Both positive and negative message checks remain.

Frozen tree `9b347b47fc96c3b457cfa80a68448d02500f0e88` passes the same sixteen checks and the Aspen1 system build. The Kagi check now runs 36 Python tests and four JavaScript tests. The new control checks that the locked row has no enable control.

The built system is `/nix/store/0dq373wying446jahqg1l2l90fpyd159-nixos-system-aspen1-26.11.20260819.afe3d8a`. The retained build log is `forge-ui-final-checks.log`.

## Remaining limits

This checkpoint does not prove deployment, complete flake acceptance, native replication, public Campaign acquisition, or lifecycle completion. Host build, live comparison, deployment, and runtime checks remain required.
