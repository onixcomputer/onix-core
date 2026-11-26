# Kiln fleet

Kiln orchestrates Britton's coding agents across his machines (OnixResearch/kiln#96). It is the claim authority every agent claims through, and it dispatches admitted implementation work to interactive agents that it starts through herdr. It follows each dispatched agent to a candidate handoff, which Kiln's own verification and publication then take over.

## Layout

| Part | Where |
| --- | --- |
| Coordinator | britton-desktop, unit `kiln-fleet` (`kiln-fleet run`), account `kiln-fleet`, state in `/var/lib/kiln-fleet`: the implementation ledger, fleet claims and sessions, verifier repositories and scratch space, candidate exports. |
| API | `http://100.110.43.11:8095` on the tailnet and `127.0.0.1:8095`. Loopback is britton-desktop; other peers are named by `tailscale whois` and must be in `modules/kiln-fleet/lib.nix` `peers`. A claim's host is always the authenticated machine. |
| Agent hosts | britton-desktop and aspen3, unit `herdr-kiln`: a headless herdr session named `kiln`, owned by `brittonr`. Watch it with `herdr --session kiln` on the host. On britton-desktop, the saved herdr machine `aspen3-kiln` targets aspen3's session. |
| Agents | Every swarm member: the `kiln-fleet` command with `KILN_FLEET_SERVER` set, and the `kiln` MCP server registered with OMP, Claude Code, Codex and Antigravity beside `swarm-news`. |
| Swarm | Kiln posts claims to `bots.claims` and questions to `bots.general` as its own swarm account `kiln` (`kiln on britton-desktop <kiln@swarm.local>`). |

The code is `modules/kiln-fleet/`:

- `coordinator.nix` (britton-desktop): the service, its account, sudo rule, vars, generated configuration and the `kiln-fleet-admit` command;
- `agent-host.nix` (britton-desktop, aspen3): the herdr session, Kiln's restricted fetch key, and the worktree root;
- `client.nix` (members): the command and the MCP registration;
- `lib.nix`: hosts, agent kinds, slots and enrolled repositories.

The flake input `kiln-fleet` pins Kiln `7210e049`, the fleet code on Kiln main (main `8f3cc39f` adds only its archived Cairn record). It is separate from the `kiln` input that kiln-web-service, the canary and the implementation guests use.

## Accounts and trust

Kiln runs as `kiln-fleet`, apart from `brittonr`, whom the dispatched agents run as. So the agents cannot write Kiln's ledger, verifier repositories or scratch space, and Kiln's candidate capture checks exactly that separation (`worker_uid` 1555). Kiln uses `brittonr` in three narrow ways:

- **herdr control:** one sudo rule lets `kiln-fleet` run a single fixed script, which runs `herdr` as `brittonr`;
- **commit fetches:** Kiln fetches agent commits over ssh with its own key (vars `kiln-fleet-ssh`). Agent hosts accept that key for `brittonr` only through a forced command, which serves `git-upload-pack` and only under `~/.local/state/kiln-fleet/worktrees`;
- **swarm posts:** Kiln posts with its own swarm key and password (vars `swarm-news-identity-kiln`, `swarm-news-password-kiln`), which aspen1 enrolls like a member.

Dispatched agents run in their own worktree with the agents' normal network and credentials. Their dispatch plans say so (`interactive_worktree` isolation), and Kiln admits such plans only for work whose policy permits the `interactive_agent` effect. The fleet proves claim bookkeeping, placement requests and observed agent states. It proves no agent's honesty; verification is Kiln's independent check of the captured commit.

## Claims

Agents claim with `kiln_claim` or `kiln-fleet claim`:

- `--scope '<owner>/<repo> <path>'`, or `<machine> <unit or path>`;
- `--tool`, `--session` and `--purpose`.

Kiln refuses a claim that overlaps another holder's open claim, the permitted paths of a live implementation attempt, or an open claim posted directly to `bots.claims`. A claim lasts 4 hours unless the agent asks for more, up to 24 hours. Agents renew it with `kiln_renew` and release it with `kiln_release`; Kiln expires unrenewed claims and posts their `RELEASE`.

```bash
kiln-fleet claims
kiln-fleet claim --scope 'onixcomputer/onix-core modules/kiln-fleet' --tool omp --session "$PWD" --purpose 'Document the fleet'
kiln-fleet release --claim <id> --fence <n> --note done
```

## Dispatching work

Kiln dispatches work from its ledger. To add work, admit a Cairn `implementation-ready` snapshot of the repository under an operator policy (`CairnImplementationPolicy`). For the fleet, the policy must:

- permit the `write_source` and `interactive_agent` effects;
- give the exact Git base, `{"contract_version": 1, "provider_namespace": "git", "native_kind": "commit", "native_id": "<sha>"}`;
- name the acceptance obligations and the paths the agent may change;
- name a verification profile stored as `/var/lib/kiln-fleet/verification-profiles/<profile id>.json`;
- belong to a repository enrolled in `lib.nix`, with a checkout on each host that may take it.

Kiln's own codec prepares the profile and prints its id:

```bash
# On britton-desktop, as root.
nix run 'git+https://seed.radicle.garden/z2wsvXm5S2sJGvuV1k5JHiwi1PbKE.git?rev=7210e049d685b652f2d6748819150c955459d096#kiln-implementer' -- \
  prepare-verification-profile --profile /tmp/profile-seed.json --output /tmp/profile.json
install -o kiln-fleet -g kiln-fleet -m 0400 /tmp/profile.json /var/lib/kiln-fleet/verification-profiles/<profile id>.json

cairn implementation-ready --root ~brittonr/git/kiln-fleet-sandbox --policy <cairn policy> > /tmp/ready.json
kiln-fleet-admit --snapshot /tmp/ready.json --policy /tmp/policy.json --sequence <n>
```

`kiln-fleet-admit` runs `kiln-cairn-intake` as `kiln-fleet` against the fleet's ledger and enrollment, so the snapshot and policy files must be readable by that account. `--sequence` must be higher than the last sequence admitted for the project.

Each tick, Kiln claims the highest-ranked ready interactive work that overlaps no open claim. Then it:

1. picks the least-loaded host with a free agent slot, reserves an interactive dispatch plan bound to that host's worktree, and claims the work's scope in the swarm;
2. creates a worktree at the base on branch `kiln/impl-<work>-<attempt>`, starts the agent and prompts it with the work's outcome, obligations, permitted paths, attempt and fence;
3. renews the attempt's lease while the agent works;
4. asks you in `bots.general` when the agent has been blocked for 5 minutes, or has stopped twice without handing off;
5. fetches the agent's commit when it calls `kiln_handoff`, checks that it descends from the base, exports the tree and admits it as a candidate handoff.

Kiln verifies and publishes with its existing commands, which the coordinator leaves unset (`verify_argv`, `publish_argv`). Cairn work verifies only through `kiln-web-service verify-implementation`, with a CI service profile and a verification profile that carries the authoritative Cairn contract. No enrolled repository has those yet, so dispatched work stops at an admitted candidate handoff.

```bash
kiln-fleet work
kiln-fleet attempts
kiln-fleet decisions
kiln-fleet answer --decision <id> --text 'Use the existing helper.'
kiln-fleet cancel --attempt <id> --reason 'superseded'
```

## Bringing it up

1. Generate the vars:
   - `clan vars generate britton-desktop --generator kiln-fleet-ssh`
   - `clan vars generate britton-desktop --generator swarm-news-identity-kiln`
   - `clan vars generate britton-desktop --generator swarm-news-password-kiln` (shared with aspen1)
   - `clan vars generate britton-desktop --generator kiln-fleet-github-token` (read-only GitHub PAT for `kiln-fleet-github-poll.timer`)
2. Deploy aspen1, which enrolls the `kiln` swarm account. Then deploy aspen3 and britton-desktop.
   - `kiln-fleet-cairn-intake.timer` periodically admits `cairn implementation-ready` snapshots for `observedRepositories` in `modules/kiln-fleet/lib.nix` into `/var/lib/kiln-fleet/implementation.sqlite` without granting automatic dispatch placement (which stays scoped to `repositories`).
   - `kiln-fleet-github-poll.timer` periodically runs `kiln-implementer poll` for `observedRepositories` with a `githubId` once `kiln-fleet-github-token` is generated.
3. On britton-desktop, save aspen3's `kiln` session as a herdr machine once: `herdr machine add brittonr@aspen3-1 --label aspen3-kiln --remote-session kiln`. If no `kiln` server is running, `machine add` starts one on aspen3 by hand, so run it only after `herdr-kiln` is up there. If `herdr-kiln` fails with `herdr server is already running`, stop that server (`herdr --session kiln server stop` as `brittonr`) and restart the unit.
4. `systemctl status kiln-fleet herdr-kiln`, `kiln-fleet claims`, and from aspen3 `kiln-fleet work`.

`herdr-kiln` does not restart on a switch, so a deploy never kills dispatched agents. After a herdr update, restart it by hand once no attempt is running.

## Current state

Since 2026-11-19, aspen1, aspen3 and britton-desktop run the fleet:

- **First dispatch.** Kiln dispatched the sandbox's Cairn change `greet-by-name` to OMP on aspen3 (attempt `bef74ee6e049`). The agent committed `dd104e7b`, and Kiln captured that commit as an admitted candidate.
- **Claims through Kiln.** Agents on aspen3 already claim through Kiln, and Kiln refuses overlapping claims.
- **Waiting on verification.** The sandbox attempt stays `candidate_produced` until verification is configured or you cancel it. While it waits, Kiln keeps the attempt's lease and the agent's slot.
- **Cancelling.** Cancelling makes the work eligible for its second and last attempt.
