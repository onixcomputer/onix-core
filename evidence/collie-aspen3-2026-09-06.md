# Aspen3 sessions in Collie

## Result

The existing desktop Collie URL now includes the `aspen3` session alias:

<https://britton-desktop.bison-tailor.ts.net/>

Aspen3 exposes three agent panes and two shell panes through that alias.
The desktop remains the primary session.
The session picker selects the host before Collie sends a pane request.
No Herdr server restart or Aspen3 deployment ran.

The desktop activated this verified system through `nixos-rebuild --store-path`:

```text
/nix/store/809lx8nxs26rkc53czi4z9cpfn5npc9l-nixos-system-britton-desktop-26.11.20260819.afe3d8a
```

Both system links resolve to that toplevel.
The build used `--no-link`, and the activation did not use the shared `result` link.

## Transport and ownership

Home Manager owns `collie-aspen3.service` and the session socket link.
The service forwards Aspen3's user-owned `herdr.sock` through SSH.
It does not forward the incompatible `herdr-client.sock` protocol.

The connection uses `brittonr@aspen3.local`, `HostKeyAlias=aspen3.clan`, and strict host-key verification.
The existing `aspen3` SSH alias has a stale LAN address, so the service uses explicit SSH arguments.
It does not forward the SSH agent or add a public TCP listener.
The runtime directory has mode 0700. The socket has mode 0600.

Only Aspen3's current default Herdr session maps to this alias.
Future named sessions need their own explicit aliases and forwards.
The desktop user must retain access to the configured SSH key agent for reconnection.

## Filesystem boundary

A socket forward carries terminal requests, not a shared filesystem.
The package declares remote aliases through `COLLIE_REMOTE_SESSIONS`.
The new policy keeps local journal reads and image uploads outside those aliases.

A real same-path journal fixture reproduced the cross-host error before the patch.
An Aspen3 history request returned desktop journal content under the original behavior.
An unsupported remote upload also created a desktop file and returned success.
The patched tests reject both behaviors.

Remote history now returns `available: false` with reason `disabled`.
Remote snapshots do not advertise journal access.
Remote image uploads return HTTP 501 before any local file write.
Local history remains available.

This integration still grants the admitted user full remote shell access.
It does not isolate existing sudo rights, credentials, or user commands.

## Validation

Before changes, the existing session, session-name, and socket-dial suites passed 38 tests.
The baseline Nix controller and integration checks also passed.
The corrected negative fixtures then reproduced three cross-host file failures.

After changes, 149 tests passed across five upstream and consumer test files.
The installed package passed its 12 remote-session tests inside a Nix check.
All six focused Nix checks passed:

- `collie-remote-sessions`
- `collie-managed-controller`
- `collie-integration`
- `herdr-workflow-plugins`
- `herdr-pueue-dashboard`
- `home-manager-2605-migration`

The full desktop system build and dry activation passed before deployment.
Scoped Statix and whitespace checks passed.

## Live evidence

An HTTPS request from Aspen1 reached the desktop bridge and ran a command in an isolated Aspen3 shell.
The command wrote `COLLIE_ASPEN3_FILE:aspen3` on Aspen3.
A direct remote read supplied execution evidence, not just the API's success response.
Existing Aspen3 agent terminal reads through Collie also returned text.

The new, unviewed test tab returned blank pane reads through Herdr's API.
The remote file probe therefore supplied the command-execution proof.
This receipt does not claim that those blank pane reads contain the command output.

During a controlled tunnel stop, Collie removed the remote alias.
Remote writes returned 404 rather than falling back to the desktop.
The desktop's primary session remained connected.
After reconnection, the same remote shell PID returned a second host-bound marker.
A separate termination of the SSH process also triggered an automatic service restart and restored the remote snapshot.

All five original Aspen3 pane and terminal identities survived.
All six original desktop pane identities survived. One additional desktop pane appeared during the check.
The owned test tab and marker file are now removed.
The `/wiki/` route remains outside this change.

## Review and remaining limits

The independent source review compared API forwarding, Herdr's thin client, a remote bridge, and shared filesystems.
It identified the cross-host file assumptions before deployment.
The worker printed its report, then reached its three-minute process limit.
The first implementation round continued into the live disconnect and reconnection checks after the source and system checks passed.

Phone interaction itself remains untested.
Remote conversation history and image uploads require a separate host-local file adapter or bridge.
The earlier desktop-local TLS mismatch remains outside this change.
Existing repository-wide Statix findings still block the commit.
I did not suppress a hook or push a change.

## Evidence location

Local artifacts are under:

```text
~/.local/state/onix/deployments/collie-aspen3-20260906/
```

The main files are `contract.md`, `architecture-review.log`, `remote-tests-before.log`, `remote-tests-after.log`, and `nix-final-checks.log`.
Deployment records are `verified-toplevel.path`, `dry-activate.log`, and `switch.log`.
Live records include `remote-command-proof.txt`, `reconnect-proof.txt`, `pane-preservation.json`, `socket-permissions.txt`, and `automatic-restart.txt`.
