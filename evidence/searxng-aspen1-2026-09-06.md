# SearXNG on Aspen1

## Deployment

- Inventory instance: `searxng-aspen1`, server role on `aspen1`.
- URL: <https://aspen1.bison-tailor.ts.net/>.
- Backend: `127.0.0.1:8888` through uWSGI.
- Tailscale Serve reports `tailnet only`. No Funnel mapping was created.
- Secret: Clan generated `searxng-searxng-aspen1/env-file` and deployed it as a private file.
- Package: `searxng 0-unstable-2026-08-13` from the existing locked nixpkgs input.
- Previous system: `/nix/store/33py77h5fwwdm7v3g7wahbp20ma2acan-nixos-system-aspen1-26.11.20260819.afe3d8a`.
- Active system: `/nix/store/wcgh305d71g8y0rqnjmh59rw9wcvnd41-nixos-system-aspen1-26.11.20260819.afe3d8a`.

The deployment used `clan machines update aspen1 --target-host root@aspen1.local --build-host root@aspen1.local --option min-free 0 --option max-free 0`.
The normal switch safety checks passed. No reboot or force option was used.
The full host deployment also applied existing configuration drift, including removal of `hermes-a2a-worker-hermes-a2a-worker.service` and its secret.

## Observed checks

- `searxng-module` and `module-registry-sync` passed before deployment.
- The module check includes positive and negative configuration tests, private secret generation, and an OpenSSL error case.
- The proxy check rejects a non-loopback backend and verifies loopback-only trusted proxies.
- `searx-init`, `uwsgi`, `redis-searx`, and `searxng-serve` all reported `active`.
- `ss` showed the backend listener only on `127.0.0.1:8888`.
- A request from the desktop to the private HTTPS root returned HTTP 200 with certificate verification enabled.
- A JSON search for `SearXNG` returned HTTP 200 and nonempty results from Brave and Google CSE.
- The search response reported CAPTCHA errors from DuckDuckGo and Startpage. Wikidata initialization reported upstream HTTP 403.
- `systemctl --failed --no-legend` returned no failed units.
- Nix formatting and `git diff --check` passed.

## Client behavior

The default bot protection rejects plain curl requests with HTTP 429.
Browser-like search requests also require valid `Sec-Fetch-*` headers. Missing `Sec-Fetch-Mode` produced a redirect to `/`.
The successful JSON probe used a Chrome user agent, browser Accept headers, compression, and these headers:

```text
Sec-Fetch-Mode: navigate
Sec-Fetch-Site: same-origin
Sec-Fetch-Dest: document
```

The checks prove the deployed page, private proxy, and one live search. They do not prove that every upstream engine is available.

## Repository state

The source commit was blocked by pre-existing Statix findings in unrelated service modules.
The repository-wide formatter also touched unrelated Collie assets and the UMA helper. Those unrelated changes were restored.
The generated secret has a Clan-managed commit. The service source remains uncommitted. No push occurred.

## Rollback

Remove the SearXNG inventory assignment and the `searxng-serve.nix` host import before a declarative rollback.
On Aspen1, disable only this Serve endpoint with `tailscale serve --https=443 off`.
The Serve mapping persists independently of the NixOS unit. Removing the unit alone does not remove the mapping.
