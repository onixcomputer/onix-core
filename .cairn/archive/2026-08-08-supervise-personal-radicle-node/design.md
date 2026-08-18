## Context

`britton-desktop` runs a machine-scoped Radicle replica under `/var/lib/radicle`. The personal Radicle profile uses `/home/brittonr/.radicle` and a different identity.

The personal node previously ran outside systemd. Its log ends with a clean termination signal and shutdown. No user unit exists to restart it.

The existing `modules/radicle-desktop/package.nix` wrapper already forces an operating-system-selected loopback port. It also rejects caller-supplied listener arguments.

## Goals

- Keep the personal node available after process termination, logout, and reboot.
- Preserve the personal identity and existing state.
- Preserve separation from the machine-scoped replica.
- Reuse the reviewed listener wrapper.
- Keep signing access bound to the user YubiKey agent.

## Non-goals

- Do not replace or reconfigure the machine-scoped replica.
- Do not copy personal keys into system credentials.
- Do not rewrite the mutable personal Radicle configuration.
- Do not change repository governance or seeding policy.
- Do not claim network availability when peers or links are unavailable.

## Decisions

### Decision: Use a Home Manager user service

**Choice:** Add a `radicle-personal-node` service to a desktop-only `radicle` profile.

The service runs in the user manager and uses `/home/brittonr/.radicle`. It starts with `default.target`.

**Rationale:** The personal node needs the user identity, state, socket, and YubiKey agent. The system replica service has a different authority boundary.

### Decision: Reuse the existing isolation wrapper

**Choice:** Build the personal package with `modules/radicle-desktop/package.nix`.

The wrapper sets `RAD_HOME`, sets `RAD_SOCKET`, forces `127.0.0.1:0`, and rejects all other listener arguments.

**Rationale:** This wrapper already has positive and negative tests for desktop and replica coexistence.

### Decision: Restart after clean external termination

**Choice:** Set `Restart=always` with a named restart delay.

An explicit `systemctl --user stop` remains authoritative because systemd does not restart explicitly stopped units.

**Rationale:** The observed termination used a clean signal. `Restart=on-failure` does not reliably restart clean signal exits.

### Decision: Bind startup to user prerequisites

**Choice:** Order the service after `yubikey-agent.service`.

The unit uses systemd's `%t` user-runtime specifier for the SSH agent socket. The service restarts if the signer is not ready.

**Rationale:** Hard-coded user IDs, ambient shell environments, and system-manager network targets are unsafe in a user unit. Radicle handles network loss after startup.

### Decision: Enable user lingering

**Choice:** Set `users.users.brittonr.linger = true` on `britton-desktop`.

**Rationale:** The user manager must survive logout and start during boot.

### Decision: Preserve the managed-port guard

**Choice:** Deny TCP port `8776` for the desktop user slice.

The personal wrapper uses an ephemeral loopback port. The managed replica retains the reviewed tailnet listener.

**Rationale:** A raw personal process must not block or impersonate the machine-scoped replica listener.

## Functional Core and Imperative Shell

The existing wrapper is the deterministic core for listener and environment selection. The systemd unit is the imperative shell for startup, restart, and process lifetime.

## Risks / Trade-offs

- A missing YubiKey agent can cause bounded restart attempts until the socket becomes available.
- The service does not repair stale seed addresses in the mutable personal configuration.
- User lingering keeps the user manager active after logout.
- A running node does not prove peer reachability or repository replication.
