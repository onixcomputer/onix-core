# Collie desktop deployment

## Result

Collie runs on `britton-desktop` and connects to eight Herdr agents.
The private URL is <https://britton-desktop.bison-tailor.ts.net/>.
Home Manager owns the bridge. NixOS owns the Tailscale Serve root mapping.
The existing `/wiki/` mapping remains present. Funnel remains disabled.

The desktop shell repair is complete.
Both system links resolve to this valid, activated toplevel:

```text
/nix/store/yls221xga9pb62q86jy6an1rh0qvggjm-nixos-system-britton-desktop-26.11.20260819.afe3d8a
```

The deployed Collie package is:

```text
/nix/store/cdf1rilrw4zmff7pmldm294xw8hjrlc4-collie-herdr-0.24.1
```

It uses upstream revision `b2d2803b3f691e9abca74f3f15bbc37307a2026e` and Bun `1.3.13`.
Later controller indentation changes produce this source package:

```text
/nix/store/8h5ypz4sid324chla3r99bk71rq8xqr7-collie-herdr-0.24.1
```

The bridge and plugin manifest match between those packages.
The controller comparison passes with whitespace differences ignored.
The final continuation did not repeat system activation or service restarts.

## Validation

Five focused Nix checks pass with direct exit-status retention and no output link:

- `collie-managed-controller`
- `collie-integration`
- `herdr-workflow-plugins`
- `herdr-pueue-dashboard`
- `home-manager-2605-migration`

The pinned upstream configuration, server, and auth-path suites pass 117 tests with zero failures.
These suites include positive and negative cases.
Statix passes for every changed Nix file. Both staged and unstaged whitespace checks pass.

The live `version` and `status` plugin actions report `succeeded` with exit code zero.
The version output is `0.24.1+b2d2803`.
The bridge and publication units are active.

Earlier Aspen1 probes passed certificate verification for `/`, `/manifest.webmanifest`, `/api/config`, and `/wiki/`.
A peer command reached an isolated Herdr shell and returned `COLLIE_PEER_OK:1695729`.
The isolated session survived a server handoff before cleanup.
The test session is now removed.

Wrong identity, invalid Host, and absent remote write Origin returned 403.
An unknown session returned 404. Malformed JSON returned 400.
Upstream intentionally permits loopback callers without an identity header.

## Trust and audit limits

The managed actions preserve the supported Nix installation workflow.
They are not a security sandbox around a remote Herdr shell.
An admitted phone can send shell commands as `brittonr`, with that user's existing credentials and sudo rights.
The upstream controller also remains callable and sources `.env` as shell code.
The [package documentation](../pkgs/collie-herdr/UPSTREAM.md#trust-boundary) states these limits.

One independent read-only worker inspected these authority boundaries.
It returned findings about shell authority, direct upstream commands, configuration execution, and test scope.
Its process reached the three-minute timeout after it printed the report.
The findings do not establish a new privilege-escalation test result.
No live root-execution probe ran.

The main audit retained runtime results and inspected four local TLS facts.
DNS resolves the hostname to the desktop's tailnet address.
The local route uses loopback, which has a wildcard HTTPS listener.
Local HTTPS still fails with curl error 60 for a hostname-mismatched certificate.
Peer TLS success does not resolve that local path.
This closeout did not change the HTTPS listener or network routes.

## Remaining blockers and operational changes

The commit hook failed on existing repository-wide Statix findings outside this change.
The changed files pass their focused lint checks, but that does not satisfy the repository-wide hook.
I did not suppress a hook. The changes remain uncommitted and unpushed.
The unrelated Aspen UMA helper remains outside the staged change.
I reversed its accidental formatter edit through a verified formatter round trip.

The desktop's `/tmp` dataset reached its 250 GiB quota during activation.
I raised the quota to 258 GiB. That operational override remains in place.
The earlier Kache cleanup removed all local interactive cache blobs, not only old entries.
Kache index recovery after that deletion remains unverified.

The oversized Herdr workspace label prevented plugin process creation with `Argument list too long (os error 7)`.
The label is now `Projects`. The plugin actions then succeeded.

Phone PWA installation and push notifications remain untested.
The app's parent-project update notice does not change the pinned Nix package.

## Retained evidence

Local logs are under:

```text
~/.local/state/onix/recovery/collie-shell-20260906/
```

The check files are `final-checks.stdout`, `final-checks.stderr`, `upstream-boundary-tests.log`, `changed-nix-statix.log`, and `focused-format.log`.
`repository-statix.log` retains the commit blocker. `closeout-source-review.log` contains the independent audit.
Runtime evidence is in `live-checks/plugin-actions-closeout.json`, `live-checks/snapshot-closeout.json`, `live-checks/serve-closeout.txt`, and `live-checks/peer-roundtrip-final.json`.
