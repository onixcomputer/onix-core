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

At baseline, generation 883's OMP provider discovers Codex and OpenCode Go
dynamically but has no Claude branch; onix-core main carried an older static
Codex-only version. Promote the retained dynamic provider from the source
cohort into main, including Claude Messages
catalog metadata and the identity/header shaping required by the proxy.
Preserve Codex and OpenCode Go API mapping and the per-machine proxy-key
reader. This also prevents a future main-based deploy from reverting those
already running models.

Deploy through the generation-managed Underclass unit, not a persistent
systemd override. Generation 883's source is not presently rooted at
`~/.local/state/onix-core/deployments/883/source`; check retained source
cohorts or compare a candidate generation's closure and dry-activation against
the live one before switching. Refuse a build that would roll back unrelated
services. The closest retained cohort enables Bootvine in place of Plymouth
and changes LibreWolf cookie policy and Niri brightness bindings; retain the
running generation's exact versions of those three source files for the
candidate. The service has a dynamic user and persistent StateDirectory; a
scoped restart preserves the SQLite pool and proxy key.

## Verification

Require the Underclass fork's full offline Rust suite, format and contract
format checks, plus a Nix build from the immutable published revision. Check
that the lock changes only the Underclass node, and the provider source change
is the retained Codex/OpenCode Go plus Claude implementation. Before switching,
compare system/unit closures and dry-activation, including the Home Manager
output; after switching, confirm that only the intended account is readmitted,
that no reset credit was redeemed, and that a Claude answer is returned through
OMP from each of the three hosts.

## Completion State

On 2026-11-15, the tested fork revision `ba72139a` and the onix-core
pin/provider commits `68521462` and `71f63e48` were published to their
respective `main` branches. Britton generation 884 runs
`/nix/store/5kas2dkyfy99ckc11gq0r7qaq66dx233-underclass-0.1.0`;
its exact candidate source is rooted at
`~/.local/state/onix-core/deployments/884/source` with NAR hash
`sha256-pZg9DsGiwEpC+A5UNMtqlzOJFZj6PSAaFNPnhRKZ1Pk=`.
The candidate restored the three unrelated policy files from the running
generation. Closure comparison found 22 paths added and 22 removed: the
Underclass package, its Home Manager provider and their generated wrappers;
the dry activation identified only the corresponding service and Home
Manager changes, with polkit restart and D-Bus reload as switch side effects.
The Underclass proxy-key file hash remained
`c02af49e0f1d7d980fe2e01682753ea2fbda9f6203b6c7e504910d08d86c78f6`;
`herdr-iroh` retained PID 3508.

The switch command returned 4 because unrelated existing ZFS quota
activation snippets for `datapool/kache-nix` and
`datapool/radicle-backup` failed and `celld.service` remained failed.
The generation link nevertheless points to 884, the managed Underclass unit
and Home Manager activation are active, and the provider link is now
Home Manager-owned. Do not interpret the nonzero switch as a successful
whole-machine activation.

The next Claude usage poll readmitted only `claude@robitzs.ch` (63% weekly
utilization); `britton@cproof.ai` remained cooling at 100%. OMP returned
three paid Claude Haiku 5.5 responses, one each from Britton, Aspen3 and
cproof Mac. Aspen3 initially routed that model to Codex because its
obsolete static `models.yml` Underclass block overrode the dynamic provider
with `openai-responses`; removing that block, while preserving
`models.yml.bak-underclass-dynamic-20261115`, fixed its normal OMP CLI
without upgrading OMP. Each host also returned a paid Codex `gpt-6-sol`
response; the service journal attributed the three Claude completions to
`claude@robitzs.ch` and the three Codex completions to
`openai@robitzs.ch`. `britton@cproof.ai` Codex remains cooling with its
weekly window exhausted, and two free Codex accounts remain disabled.
There were no `codex.reset.account` redemptions; the cooling Pro Codex
account retained all three banked resets, and no OAuth login was changed.
