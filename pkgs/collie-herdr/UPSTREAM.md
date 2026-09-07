# Collie source and operation

- Source: `umakers/collie-herdr`, a fork of `AltanS/collie`.
- Revision: `b2d2803b3f691e9abca74f3f15bbc37307a2026e`.
- Version: `0.24.1`.
- Frontend build: Bun `1.3.13`, with the upstream lockfile.
- License: MIT. The package includes the upstream license.

## Package boundary

`dist/` contains the upstream Vite/React build from `web/dist`.
The frontend dependency fetch failed in the sandbox during installation.
The cause was not established. The committed frontend removes network access from package builds.

`default.nix` fetches the bridge and upstream scripts at the same revision.
Nix requires the recorded SHA-256 source hash for `fetchFromGitHub`.
The package generates a restricted plugin manifest and installs `managed-ctl.sh` as the controller.

The controller permits `start`, `stop`, and `restart` through the existing Home Manager unit.
It delegates `status`, `url`, `version`, and the explicit `push-test` command to the upstream controller.
Under the managed environment, the first three commands report state without service changes.
The managed entry point rejects package updates, builds, uninstallation, and publication changes.
Its supported actions do not enable, disable, or rewrite a service unit.

## Deployment boundary

The Herdr package includes the static `herdr.collie` plugin.
Only `britton-desktop` enables the bridge and its managed environment files.
The bridge uses the existing Herdr socket and retains state under `~/.local/state/collie`.
The controller uses the same state directory.

The NixOS `collie-serve.service` owns the HTTPS root mapping.
It preserves other paths, including `/wiki/`, and does not enable Funnel.
The bridge binds to loopback. Tailscale Serve supplies the identity header.
`COLLIE_TRUSTED_USER` restricts requests that carry that header to the configured tailnet user.
Upstream also trusts local callers without an identity header.

Do not set `COLLIE_SKIP_SERVE=1` for this deployment.
The upstream command removes an existing mapping before it skips publication.
The managed controller prevents that command from running instead.

## Aspen3 sessions

The desktop adds Aspen3's default Herdr session under the `aspen3` alias.
The phone uses the existing Collie URL and session picker.
No Collie service or public Herdr listener runs on Aspen3 for this integration.

The desktop user service `collie-aspen3.service` forwards the remote JSON API socket through SSH.
It connects as `brittonr`, verifies the `aspen3.clan` host certificate, and does not forward the SSH agent.
Its private runtime socket appears in Collie's existing session-discovery layout through a Home Manager link.
The service retries after connection loss. Collie retains the desktop's primary session during remote outages.
The SSH key agent must remain available for reconnection.

The package applies `remote-sessions.patch` and includes the pure policy in `remote-sessions.ts`.
`COLLIE_REMOTE_SESSIONS=aspen3` declares that this alias does not share the desktop filesystem.
Live state, terminal reads, replies, keys, and terminal creation use the remote API.
Remote conversation-history reads return unavailable, and remote image uploads return an explicit error.
This prevents same-path desktop journals or desktop upload paths from entering Aspen3's session.
Local session history remains available.

Additional named sessions on Aspen3 require their own explicit aliases and forwards.
This deployment admits only Aspen3's current default session.

## Trust boundary

An admitted phone can send arbitrary shell commands through Herdr as `brittonr`.
Those commands retain the user's existing sudo rights and SSH credentials.
Nix ownership controls the supported installation workflow, not the authority of that remote shell.
The bridge's `NoNewPrivileges` flag does not constrain commands in the separate Herdr process.

The package retains `scripts/collie-ctl-upstream.sh` for delegated commands.
That script sources `.env` as shell code and retains its upstream mutation commands.
Direct script calls bypass the managed command restrictions.
The managed environment file uses immutable store content, but a caller can select another configuration directory.

**CAUTION: Do not supply an untrusted `HERDR_PLUGIN_CONFIG_DIR` or `.env` to controller commands.**
Even `version` can run shell code from that file.
This deployment is not a sandbox against an admitted user or a compromised phone on that user's account.

## Verification

Run the focused checks without an output link:

```sh
nix build --no-link --no-write-lock-file \
  .#checks.x86_64-linux.collie-managed-controller \
  .#checks.x86_64-linux.collie-integration \
  .#checks.x86_64-linux.collie-remote-sessions \
  .#checks.x86_64-linux.herdr-workflow-plugins
```

The controller checks cover allowed calls, rejected calls, shared state, and propagated systemd errors.
The integration check reads evaluated service values and generated units, not Nix source strings.
It also checks that other hosts do not inherit this deployment.
The remote-session tests cover host routing with duplicate pane IDs, invalid configuration, unknown sessions, and blocked cross-host file operations.

**CAUTION: Do not use a shared `result` link for system activation.**
A check build can replace that link with a non-system output.
Use the normal deployment command and retain its failure status.
Do not pipe a build or activation command through `tail`.

## Frontend regeneration

1. Clone the upstream repository with `gh repo clone umakers/collie-herdr` into a fresh directory.
2. Select the required immutable revision.
3. Use Bun `1.3.13` for the current revision.
4. In `web/`, run `bun install --frozen-lockfile`.
5. Run `bun run build`.
6. Replace this package's `dist/` with that `web/dist/` directory.
7. Update the source pin, source hash, and version records together.
8. Verify the version and short revision in `dist/build-info.json`.
9. Run the focused checks.
