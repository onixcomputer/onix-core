# Collie crew on three hosts

## Result

Collie 1.14.1 from `AltanS/collie` runs as one crew.
The phone URL stays the same: <https://britton-desktop.bison-tailor.ts.net/>.

- `britton-desktop` is the lead.
  NixOS still owns the front door: `collie-serve.service` publishes `/` to `127.0.0.1:8787`.
  The `/wiki/` mapping still answers.
- `aspen3` is a peer.
  Its crew listener binds `100.108.13.4:8787`, and `tailscale0` is a trusted interface on that host.
- `cproof-brittonr` (the Mac) is a peer.
  The macOS application firewall drops inbound connections to ad-hoc-signed store binaries.
  A store `socat` listener on the tailnet address confirmed this.
  The peer listener therefore stays on `127.0.0.1:8787`.
  `tailscale serve --tcp 8787 tcp://127.0.0.1:8787` forwards the lead's mutual-TLS dial to it.
  `collie doctor` reports that bind as an error, but the lead reports the link as reachable.

The lead's snapshot lists three reachable servers.
It returned agent and shell panes for all three hosts: 6 on the desktop, 10 on aspen3 and 7 on the Mac.
Through the front door, `GET /api/pane/<id>?host=<member>` returned HTTP 200 with terminal text for one pane on each host.

## Ownership

Collie owns its user unit, its `.env` and its crew state.
Every crew verb rewrites and restarts `~/.config/systemd/user/collie.service`, or `~/Library/LaunchAgents/herdr.collie.plist` on the Mac.
`collie start` writes `COLLIE_MUX` into the `.env`.
A Home Manager link at any of these paths makes the verb fail after it has stopped the bridge.

- Package: `nix profile install github:AltanS/collie/ed70203fd04701d72b921d0042384a328e2b96fc#collie` on each host.
  The `v1.14.1` tag still pins the 1.14.0 tarball in `packaging/nix/sources.json`.
  Commit `ed70203` is the first commit that pins 1.14.1.
  To update, run `nix profile upgrade collie` and then `collie restart`.
- Config: `~/.config/herdr/plugins/config/herdr.collie/.env` on each host, mode 0600.
- Crew state: `~/.local/state/collie/crew-*.json`.

The lead does not set `COLLIE_SKIP_SERVE`, so it still rejects a request with no `Tailscale-User-Login`.
Collie's own `tailscale serve` call on the lead fails with `Access denied`, because `brittonr` is not the Tailscale operator.
`collie doctor` therefore reports `front-door` as an error.
Both results are expected.

## Working-tree change (not deployed)

- `inventory/home-profiles/brittonr/herdr/default.nix` no longer declares the 0.24.1 bridge unit, the two `.env` links or the `collie-aspen3` forward.
  sd-switch stops a unit that leaves the generation, and the old unit also had the name `collie.service`.
  For that reason `home.activation.startCollie` starts Collie's own unit after `reloadSystemd`.
- `collie.env` and `lib/collie-aspen3.nix` are deleted.
- `flake-outputs/_collie-herdr-integration-check.nix` checks four things:
  - no host's Home Manager declares a Collie unit;
  - no host links a Collie `.env` or the remote socket;
  - the desktop and aspen3 have the activation hook;
  - `brittonr` has no Tailscale operator role.
- `_home-manager-checks.nix` drops the `.serve` verify marker, because `desktop-tailnet-proxy` checks the front door.

## Validation

- `nix build .#checks.x86_64-linux.collie-integration` passed on the working tree.
- `nixfmt --check`, `deadnix --fail` and `statix check` passed for the three changed Nix files.
- The rendered `startCollie` script ran against the live lead with stub `run` and `warnEcho` functions.
  It exited 0, and the unit stayed active.
- On the lead, `collie crew status` showed both members with `link reachable`, secret generation 1 and version `1.14.1+29126a3`.

## Runtime changes on britton-desktop

Home Manager had installed these files as links:

- the old bridge unit;
- the two `.env` files;
- `collie-aspen3.service`;
- the `herdr/sessions/aspen3/herdr.sock` link.

All of them were stopped and removed. `pre-state.txt` records the state before the change.
`collie-aspen3.service` was already in a restart loop before the change.

## Remaining limits

- A reboot before the desktop deploys this working tree runs the old Home Manager generation.
  That generation restores the 0.24.1 unit and the `.env` links, and moves Collie's files to `.hm-bak`.
  To recover, remove the same links again and run `collie start`.
- The Herdr wrapper still bundles the 0.24.1 `herdr.collie` plugin.
  The relevant files are onixpkgs `pkgs/herdr`, `lib/config.ncl` and `workflowPluginSources`.
  Its start, stop and restart actions operate on Collie's own `collie.service`.
  Its status, url and version actions still run 0.24.1 code.
- `collie crew invite` prints `collie crew join <host>:443`, and that command fails with `Unable to connect`.
  `leadOrigin` drops the default port 443 and then applies 8787.
  Join with `https://britton-desktop.bison-tailor.ts.net` instead.
- During the check, aspen3's Wi-Fi carried about 4 MiB/s inbound and 3 MiB/s outbound.
  TCP connects from the desktop to aspen3 took from 88 ms to more than 5 s.
  The Mac is on the same site and answered in 55–65 ms.
  Under that load, the crew link to aspen3 can drop out.
- No device is paired. Run `collie pair` on the lead and scan the code from the phone.
- Push notifications are off until `collie push-keys` runs on the lead.
- On aspen3, `python3` is not on the PATH that the agents use, so Herdr's agent-state hooks cannot report sessions.
  `collie doctor` reports this as `hook-python3`.
- Before the Mac leaves the crew, run `tailscale serve --tcp 8787 off`.
  A solo bridge behind that forward is reachable from the tailnet.

## Evidence location

Each host keeps its artifacts under `~/.local/state/onix/deployments/collie-crew-20260927/`.
The files are `pre-state.txt`, `lead-start.txt`, `member-start.txt`, `join.txt`, `crew-status.txt`, `doctor-crew.txt`, `check-collie-integration.log`, `lint.log` and `startCollie.sh`.
