## Context

buildbot-nix already runs on aspen1, building all `checks` (machine configs, vars, packages, devShells) on every push and PR. The `update-prefetch` timer on each machine polls buildbot's outputs index hourly and auto-switches to new system closures. `merge-when-green` watches PRs and auto-merges when CI passes. The missing piece is automated input updates — currently manual `nix flake update` runs.

buildbot-nix supports hercules-ci-compatible effects: `onPush` (triggered by git push) and `onSchedule` (cron-like). Effects run inside bubblewrap with network access and injected secrets at `/run/secrets.json`. The flake exports a `herculesCI` function; buildbot-nix evaluates it, discovers schedules, and creates Buildbot `Nightly` schedulers.

Mic92's dotfiles use `onPush` effects for codecov uploads. The `onSchedule` API is the same pattern but triggered by time instead of push events.

## Goals / Non-Goals

**Goals:**
- Automate `nix flake update` on a recurring schedule (2x/week)
- Create PRs that buildbot evaluates and verifies before merge
- Close the loop with existing merge-when-green + update-prefetch for hands-off deployment
- Store the GitHub PAT secret via clan vars (SOPS-encrypted, same pattern as existing buildbot secrets)

**Non-Goals:**
- Per-input selective updates (update all inputs together for simplicity)
- Auto-merge without CI verification (PRs go through normal buildbot checks)
- Scheduled effects for other tasks (gc, security scans) — future work, not this change
- Renovate or other external dependency update tools

## Decisions

### 1. herculesCI output location

**Choice:** New file `flake-outputs/effects.nix` imported into the `modules` list of the `adios-flake.lib.mkFlake` call.

**Rationale:** Keeps effects alongside other flake-output modules (checks.nix, dev-env.nix, tools.nix). The `herculesCI` output is a top-level flake attribute, set via the `flake` attrset that adios-flake passes through.

**Alternative considered:** Inline in `flake.nix` — rejected because the effect derivation is non-trivial and `flake.nix` is already 150+ lines of inputs.

### 2. GitHub authentication for PR creation

**Choice:** Personal Access Token (fine-grained) with `contents:write` + `pull_requests:write` on onix-core. Stored via clan vars generator, wired through `effects.perRepoSecretFiles`.

**Rationale:** The buildbot GitHub App already has repo access, but effects secrets use the hercules-ci JSON format (`{ "github": { "data": { "token": "..." } } }`), which expects a plain token. A fine-grained PAT scoped to one repo is the simplest path. The existing `buildbot-github` vars generator handles app keys separately and shouldn't be mixed.

**Alternative considered:** Using the GitHub App installation token — would require extracting the JWT flow inside the effect, adding complexity for no benefit since we only need one repo.

### 3. Schedule frequency

**Choice:** Monday and Thursday at 04:00 UTC (midnight EDT).

**Rationale:** 2x/week catches breakage within ~3 days without creating noise. Monday catches weekend nixpkgs changes; Thursday catches mid-week. 04:00 UTC avoids peak hours and gives buildbot time to evaluate + build before the morning.

### 4. Branch naming and dedup

**Choice:** Branch name `auto/flake-update-YYYYMMDD`. If a branch or open PR already exists for the same day, the effect exits early without creating a duplicate.

**Rationale:** Date-based naming makes it obvious what the PR is. Dedup prevents stacking identical PRs if the schedule fires twice (e.g., buildbot restart). The `auto/` prefix distinguishes from human branches.

### 5. Eval-only pre-check inside the effect

**Choice:** Run `nix flake check --no-build` inside the effect before pushing, to catch eval failures early. If eval fails, still push the branch and create the PR, but tag the PR body with a warning.

**Rationale:** Full builds are expensive and that's buildbot's job. But a quick eval catches obvious breakage (removed options, type errors) in seconds. Pushing anyway ensures visibility — a broken update that's never pushed is silently lost.

## Risks / Trade-offs

- **[Stale PAT]** Fine-grained PATs expire (max 1 year). → Set a calendar reminder. Consider switching to GitHub App installation tokens later if this becomes a pain.
- **[Merge conflicts]** If a human pushes to main between the effect's clone and push, the PR branch may conflict. → merge-when-green already handles this by rebasing. Worst case, the PR needs manual rebase.
- **[Eval OOM in effect]** `nix flake check --no-build` inside bubblewrap may hit memory limits on large flakes. → The check is best-effort (exits 0 on failure). The real eval happens in buildbot's eval workers with proper memory limits.
- **[GitHub rate limits]** One PR creation + one branch push per run is well within limits (5000 req/hr for authenticated users).
- **[Effect sandbox escapes]** Effects run in bubblewrap with network access. The PAT is scoped to one repo with minimal permissions. → Acceptable risk, same trust model as existing buildbot workers.
