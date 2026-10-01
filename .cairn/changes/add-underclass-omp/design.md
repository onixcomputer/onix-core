## Context

The `omp-agents` Clan instance installs OMP on `britton-desktop` and `aspen3`. Existing research tools are separately managed extensions. Underclass's `connect` command edits OpenCode configuration, not OMP.

## Decisions

### Decision: Local pools and additive OMP provider

**Choice:** Reuse the upstream NixOS module, enable it only alongside the existing OMP instance, bind `127.0.0.1:8080`, and keep the firewall closed. Store persistent pool state in the upstream dynamic-user state directory. Install a native extension with a runtime client-key command, leaving existing OMP auth, model definitions and default choices untouched.

**Rationale:** Localhost is the upstream security default. Separate device-flow logins give each pool ownership of its refresh tokens, avoiding token-rotation races with OMP or another machine. The existing Home Manager extension pattern is additive and reloadable.

### Decision: Credentials and quota credits remain controlled

**Choice:** Generate independent random proxy and UI keys per machine with Clan vars. Give the selected local user read-only access to client/admin keys and reserve the service environment file for root. Disable automatic Codex banked-reset redemption.

**Rationale:** Nix store artifacts contain only runtime paths, never credentials. Model access must not implicitly spend banked reset credits. Account enrollment remains an explicit upstream device-flow authorization.

### Decision: Native Responses transport and catalog intersection

**Choice:** Register a separate `underclass` provider with `openai-responses`, runtime command-backed authentication and `omitMaxOutputTokens = true`. Advertise the intersection of Underclass's seeded Codex IDs and OMP's bundled Codex metadata. Copy capabilities and limits, not the original provider URL/API or resolved compatibility flags.

**Rationale:** OMP's Codex transport appends `/codex/responses`, which Underclass does not expose. Generic Responses reaches `/v1/responses` and supplies the session's `prompt_cache_key`, but normally sends an output-token cap rejected by Codex. The actual OMP 18.2.4 bundle no longer contains the older GPT-5.4 family; requiring every seeded ID would prevent the entire extension from loading. The native smoke verified five advertised models, authenticated SSE requests, stable cache keys, `store:false`, omitted output caps and the real empty-pool error.

### Decision: Aspen3 shares the desktop pool

**Choice:** Aspen3 sets `ompUnderclassRemoteHost = "britton-desktop"` instead of `ompUnderclass`. It runs no Underclass service and generates no Underclass vars. A Home Manager `underclass-ssh-tunnel` user service forwards Aspen3's `127.0.0.1:8080` to the desktop listener, and the provider reads the desktop's proxy key over SSH at request time. An assertion rejects enabling both modes on one machine.

**Rationale:** The desktop pool already holds the enrolled Codex identities. A second Aspen3 pool would need separate enrollments and would split account affinity. The desktop listener stays loopback-only; SSH carries both the traffic and the key lookup.

## Risks / Trade-offs

- Each machine that runs the service needs its own account enrollment. Shared-pool clients such as Aspen3 depend on the desktop service and an SSH session to it.
- No account is fabricated or imported from OMP. Inference cannot succeed until the operator authorizes an account in the local UI.
- Upstream's local monitor socket exposes account labels and usage to local users; it does not expose account tokens.
- Preserve current system state during verification; do not activate unrelated working-tree changes.

## Activation and use

Britton-desktop scoped activation on 2026-09-24 uses the reviewed isolated worktree at `/home/brittonr/git/onix-core-underclass-stage`. Three encrypted per-machine Clan vars were generated there. Only those three decrypted files were installed under `/run/secrets/vars/per-machine/britton-desktop/underclass/`; the evaluated unit was linked under `/run/systemd/system/` with `systemctl --runtime`, and the OMP extension was linked from the built store artifact. No NixOS generation was switched. The service and its authenticated routes run on loopback. Three separately authorized Codex identities now match all three active OMP OpenAI identities. At verification, one account was healthy and two were cooling on quota; OMP generated a GPT-5.5 response through the healthy account. A fourth distinct identity with stale, disabled OMP credentials was not enrolled. Anthropic subscriptions remain directly authenticated in OMP, not pooled by Underclass.

Aspen3 first used the same isolated worktree with `ompUnderclass = true` and its own three per-machine Clan vars, installed only under `/run`. Later on 2026-09-24 it was switched to the desktop pool: the local runtime service was removed, and a hand-installed `underclass-ssh-tunnel` user unit and provider extension read the desktop proxy key over SSH. The isolated worktree's `ompUnderclassRemoteHost` mode records that arrangement. Aspen3's own Underclass vars exist only in the isolated worktree, and its unused pool database remains under `/var/lib/private/underclass`. No OAuth tokens were copied between hosts.

This is **not a durable Clan deployment** for britton-desktop: `/etc/systemd/system` is a read-only Nix-store symlink, so the runtime unit and `/run` secrets disappear on reboot, while `/var/lib/underclass/pool.db` persists. Keep the isolated worktree until the desktop is deployed; its `result-underclass-unit` and `result-omp-underclass` links retain the built desktop artifacts. A full britton-desktop host build from that isolated baseline currently fails because its pinned Nixpkgs lacks `electron_44` required by T3Code. Do not switch the desktop's unrelated dirty working tree as a shortcut. Aspen3 was deployed through Clan from the main working tree on 2026-09-26 (`restore-aspen3-clan-deploy`); its hand-installed tunnel unit and extension were first moved to `~/.local/state/underclass-aspen3/pre-clan-backup/`. The current Codex OMP extension remains independent of the direct Anthropic default.

The Underclass module changes and the desktop's encrypted vars are now in the main working tree, and Aspen3 runs them. For the desktop, remove its temporary runtime unit and manually linked OMP extension before NixOS and Home Manager manage them, then deploy it through Clan. Until then, Aspen3's provider cannot read `/run/secrets/vars/per-machine/britton-desktop/underclass/proxy-key`: a later desktop activation removed that runtime secret, although the desktop service still runs.

1. On each machine that runs the service, generate any missing per-machine credentials with `clan vars generate <machine> --generator underclass`, then deploy the reviewed machine configuration through the normal Clan workflow. Shared-pool clients such as Aspen3 have no Underclass vars. Before generation, Clan intentionally evaluates undeployed secret paths as `/no-such-path`; those evaluated service/provider artifacts are not ready for activation.
2. On each service machine, retrieve its admin token with `clan vars get <machine> underclass/ui-token` from the authorized repository checkout. Treat the output as a secret.
3. Open `http://127.0.0.1:8080`, enter that admin token, and enroll subscriptions through **Add account**. Authorize separately on each service machine; do not copy an existing OMP refresh token.
4. Start a new session with `omp --model underclass/gpt-6-astra`. Do not use `--provider underclass` on a cold extension-provider launch; OMP resolves the combined selector after loading extensions.
5. Run `utop` on the service machine to inspect its pool. Existing default models and research extensions remain unchanged. Native OMP cache retention must not be disabled if session affinity is desired.

The current provider exposes GPT-5.5, GPT-5.6 Luna/Sol/Terra and GPT-6 Astra. Copilot-only models with other wire formats are not advertised by this Responses integration. Model visibility is not evidence of an enrolled or quota-ready account. OMP applies its normal retries to an empty-pool 503; no direct-provider fallback is installed.

Restart `underclass.service` after rotating its environment-file credentials. Restart OMP to discard its cached command-resolved client key.

Observed build and runtime results are recorded in `verification.json`. Live GPT-5.5 generation on britton-desktop succeeded after three separate OAuth enrollments. Aspen3 has no pool of its own; its inference through the desktop pool stays unverified until the desktop proxy key is installed again.
