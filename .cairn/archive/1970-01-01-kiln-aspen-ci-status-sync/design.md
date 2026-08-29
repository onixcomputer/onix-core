# Design: Kiln Aspen CI status sync

## Failure boundary

The broker writes CI job COBs through its own COB adapter and then asks the
local Radicle node to announce the bot namespace. The announce step fails on
status updates with `no refs were announced`, so the owner node does not
learn about new status until something else triggers a sync. A manual
`rad sync` for the admitted repository was verified to make the owner node
fetch the job COB references, for both the failed job
`235f50cb19802b8a8c9f316ed42d21a8415d754f` and the successful job
`7b45072ccfd03a4c15318205fb7a0bde7ddb4724`.

The seed node's storage is the authority for what is announced. The bot
namespace signed-refs file under that storage changes exactly when the
broker writes CI status, so it is the correct trigger signal.

## Chosen mechanism

1. Add `kiln-aspen-ci-status-sync.path` watching
   `${settings.sourcePath}/refs/namespaces/${ciStatusNamespaceNodeId}/refs/rad/sigrefs`
   with `PathChanged`, matching the proven `source-refresh` path pattern.
2. Add `kiln-aspen-ci-status-sync.service`, a oneshot running
   `rad sync <repository>` as the `radicle` user with `HOME` and `RAD_HOME`
   pinned to the Radicle state directory.
3. Restrict the oneshot to `RestrictAddressFamilies = [ "AF_UNIX" ]` because
   the CLI talks to the node control socket and the node owns networking.
4. Bind the sync to a `RuntimeMaxSec` bound so a stuck sync cannot hold the
   trigger open; systemd path units re-arm after the oneshot exits.
5. Pin the bot namespace node id inline next to the existing pinned
   `sourceOwnerNodeId`, because the production cohort already pins exact
   node identities.
6. Document the announce limitation, the manual remedy, and the CLI profile
   repair procedure in the module README.

## Approach-family registry

| Family | Mechanism | State | Evidence / gap |
| --- | --- | --- | --- |
| Path-triggered bounded sync | Watch bot sigrefs, run bounded `rad sync` | validated | Manual sync propagated both jobs; the trigger reuses the source-refresh pattern |
| Upstream broker fix | Retry or tolerate empty announce in `radicle-job` | blocked as stronger | Requires vendored crate changes outside this repository |
| Node-side storage watching | Teach radicle-node to announce local writes | blocked as stronger | Upstream node behavior change |
| Unrestricted periodic timer | Run `rad sync` on a fixed interval | audit | Simpler but polls instead of reacting to status writes and widens nothing |

## Adversarial audit

Verification SHALL reject a patch that lets the sync unit run as root, open
internet address families, sync an unbounded repository set, restart or
redispatch any production runtime unit, or exceed its runtime bound. The
positive path SHALL assert the exact watched sigrefs path, the exact
repository argument, and the unix-only address families. The negative path
SHALL assert the units are absent when the runtime is disabled and that the
sync unit carries no network address family.

## Search budget

Three mechanism families, one implementation round, focused Nix eval
checks, and one live event verification. Search stops when the offline
module checks pass and the live event shows propagation without operator
action.

## Claim boundary

This change proves only that the production module triggers a bounded sync
after status writes and that the sync ran. It does not prove remote CI
correctness, remote status delivery to every peer, release eligibility, or
broker announce correctness.
