# Aspen1 agent tag and Kagi panel

The user confirmed that Kagi worked in their Aspen3 browser after the correct engine key reached its clipboard through an approved SSH transfer.
The user then requested removal of the unlocked access panel from search results.

## Changes

- `modules/searxng/kagi-access.html` hides the ready panel on results pages only.
- Preferences retains the panel. Missing, rejected, and unavailable states retain their diagnostics on results pages.
- `modules/searxng/test_kagi_session.py` tests both endpoints across all four states.
- `inventory/core/machines.ncl` restores the user-requested `llm-client` tag to Aspen1.

## Deployment safeguards

The baseline and updated SearXNG checks passed.
The initial Clan deployment stopped on an unrelated Drift source-snapshot error.
An Aspen1-only build succeeded, but its preview removed Hermes, Pi, and OpenSpec. That candidate was not activated.
The three packages belong to the `llm-agents` service, which selects the `llm-client` tag. Aspen1 lacked that tag in the source inventory.
The user explicitly requested restoration of the tag.

After restoration, package evaluation reported all three required packages present. The system build passed.
The new preview showed no package removals. It added `crw`, `ollama`, and `opencode` through the tag's existing configuration.
Activation required the live system to match the reviewed preview baseline before proceeding.
No secret generation, secret rotation, or manual Nix store edits occurred.

## Live evidence

Task 1416 activated `/nix/store/2zxpsbc6m6xagfjwd6sz93ji1zifqahj-nixos-system-aspen1-26.11.20260819.afe3d8a`.
All four SearXNG units were active afterward.

Task 1421 used a fresh Chromium context through an SSH SOCKS proxy on Aspen3, not the user's browser profile.
It used the user's exact search URL and confirmed:

- 20 results, all labeled `kagi-private`;
- no access panel on unlocked search results;
- the panel remains on locked search results;
- the unlock form remains in Preferences;
- other preferences and tokens remain unchanged;
- incorrect keys fail;
- a deliberately discarded cookie produces the missing-cookie diagnostic.

Credentials passed through standard input and browser memory. They were not included in the receipt or command arguments.
No push occurred.
