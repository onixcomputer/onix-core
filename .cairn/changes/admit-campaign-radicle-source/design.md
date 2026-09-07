## Context

The existing Nickel inventory derives public seed and HTTPS repository sets from `radicle_source_rids`.
The replicas are `britton-desktop` and `aspen3`. Aspen1 also serves read-only HTTPS Git.
Campaign already has a signed publisher namespace. The forge does not currently admit its RID.

## Goals

- Serve the exact reviewed Campaign revision through the existing forge.
- Add only Campaign to the public repository set.
- Preserve private, CI, delegate, credential, and unrelated host state.

## Non-goals

- Change Campaign policy, consumer integration, or KVM behavior.
- Create a mirror or change canonical refs.
- Upgrade Radicle or override failed policy gates.

## Decisions

### One declared public set

Add one named Campaign RID to the existing Nickel list. Existing modules lower the list to seed policies and HTTPS routes.
Reuse their validation and reconciliation code. No new executor or policy mechanism is necessary.

### Exact policy checks

A focused check reads the real Nickel inventory. It requires identical public sets on Aspen1, desktop, Aspen3, and HTTPS.
It checks the unchanged private sets, CI repository, and signed-reference requirement.
Negative cases remove Campaign, duplicate it, add an unknown RID, cross public and private scope, or expand CI scope.
These checks establish declared policy only. They do not establish deployment or replication.

### Keep formatting inside the worktree

The existing formatter searches for `.git/config`. A linked worktree has a `.git` file, so that search can reach the parent repository.
Use `flake.nix` as the root marker. A regression fixture requires child formatting and an unchanged parent file.
Keep all formatters and lint gates enabled.

### Preserve deployed systems

Use the documented Clan deployment path with strict host-key checks.
Before deployment, compare the candidate configuration with the current host configuration.
Stop if the candidate removes unrelated live services or if the current host source cannot be reproduced safely.
Do not copy dirty primary changes into this branch, replace live configuration with an older base, or install runtime policy overrides.
Retain each current system closure for rollback. Do not replace node identities or read secret contents.

### Exact source acquisition

After deployment, use the service-owned reconciler rather than the root Radicle profile.
Verify that the publisher revision is available through native replication and a fresh HTTPS checkout.
Compare BLAKE3 archive identities and run Git object validation.
Probe unknown repositories, write discovery, write endpoints, and the HTTPS root for rejection.
Keep observation evidence separate from declared policy tests.

## Risks

A clean origin/main worktree can omit unrelated services that a dirty primary checkout deployed.
A passing new check cannot override a failing existing node-policy gate.
A local namespace push cannot establish network replication.

## Validation

Run the existing node and replica policy checks before and after the change.
Run the focused admission check, including negative cases.
Run the Cairn proposal, design, and task gates before implementation.
Require safe host comparison, successful deployment, exact source acquisition, and rejection probes before archive.
