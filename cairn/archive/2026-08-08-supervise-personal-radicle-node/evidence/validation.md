# Validation Evidence

Date: 2026-08-08
Host: `britton-desktop`

## Baseline

Before implementation:

- The focused Home Manager evaluation passed.
- `radicle-personal-node.service` was absent.
- The personal node was stopped.
- `~/.radicle/node/node.log` ended with a clean termination-signal shutdown.
- `radicle-node.service` did not exist in the user manager.

The full `origin/main` desktop build was tested in a detached worktree. It failed because `devenv-2.2.1` and `secretspec-0.17.0` both provide `bin/secretspec` in `home-manager-path`. The implementation worktree fails at the same pre-existing derivation.

## Static and evaluation checks

The following checks passed:

```console
nix shell nixpkgs#nickel -c nickel export inventory/core/users.ncl
nixfmt --check inventory/home-profiles/brittonr/radicle/default.nix machines/britton-desktop/configuration.nix flake-outputs/_personal-radicle-node-checks.nix flake-outputs/checks.nix
nix build .#checks.x86_64-linux.personal-radicle-node-supervision -L
nix build .#checks.x86_64-linux.radicle-seed-replica -L
git diff --check
```

The focused check proves these evaluated facts:

- Only `britton-desktop` contains `radicle-personal-node.service`.
- The service uses `/home/brittonr/.radicle` and its personal control socket.
- The wrapper forces `127.0.0.1:0` and rejects listener overrides.
- The service waits for `yubikey-agent.service`.
- `SSH_AUTH_SOCK` uses systemd's `%t` user-runtime specifier.
- `Restart=always`, `RestartSec=10s`, and unlimited start retries are active.
- The user default target enables the service.
- The evaluated desktop user has lingering enabled.
- The evaluated desktop user slice denies `tcp:8776`.
- Laptop and server profiles do not contain the service.
- The personal service does not reference `/var/lib/radicle` or system credentials.

The existing replica check also passed its positive wrapper test and negative explicit-listener tests.

## Full desktop build boundary

This command was run:

```console
nix build .#nixosConfigurations.britton-desktop.config.system.build.toplevel -L
```

It reached and built the generated Radicle package, user unit, linger unit, and user slice. The build then failed in the unrelated `home-manager-path` package collision described in the baseline section.

The same failure occurs on an unmodified detached `origin/main` worktree. This change does not add `devenv` or `secretspec`.

## Live activation

Because the full generation has a baseline blocker, the exact evaluated Home Manager unit was realized separately. It was rooted at:

```text
/home/brittonr/.local/state/onix/radicle-personal-node-unit
```

The unit was linked into the user manager and enabled. User lingering was enabled with `loginctl enable-linger`.

Observed state:

```text
service=radicle-personal-node.service
state=active
linger=yes
command=radicle-node --listen 127.0.0.1:0 --force
node_id=z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx
listen=127.0.0.1:41979
peer_connections=8
```

The listener port is an operating-system-selected observation. It is not a configured constant.

## Restart and explicit-stop probes

The main process received `SIGTERM` through the user manager. After the declared restart delay:

```text
before_pid=489860
after_pid=493279
node_id=z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx
```

The PID changed, the service returned to active, and the personal node identity did not change.

The service was then stopped explicitly. It remained inactive beyond the restart delay. A final explicit start returned it to active.

## Known warnings

The mutable personal Radicle configuration still reports deprecated seed hostnames and unbracketed IPv6 seed addresses. These warnings did not stop startup or peer connections. This change does not rewrite mutable personal policy.

## Lifecycle receipts

The accepted specification sync completed with receipt hash:

```text
f4bd89b106cf4363e62d55b9b4d6458501013afb0dcbad4df2d44c324d2b27f5
```

## Non-claims

- An active node does not prove continuous peer reachability.
- Eight observed peers do not prove global replication.
- The live generated-unit bridge does not activate the evaluated system-slice bind guard.
- The full declarative desktop generation remains blocked by the baseline package collision.
- The personal service does not own machine-scoped replica identity, credentials, seeding policy, or release authority.
