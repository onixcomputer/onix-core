# SearXNG Clan service

This service provides [SearXNG](https://github.com/searxng/searxng), a metasearch engine, through the locked NixOS `services.searx` module.
It uses the `searxng` package from the existing locked nixpkgs input.
It does not add a container or another flake input.

## Configuration

Add an instance to `inventory/services/services.ncl` with a selected machine:

```nickel
"web-search" = {
  module = { name = "searxng", input = "self" },
  roles.server.machines.aspen1.settings = {
    bindAddress = "127.0.0.1",
    baseUrl = "https://search.example.net/",
  },
},
```

The listener defaults to `127.0.0.1:8888`. The firewall remains closed.
The service supports one instance per machine because the NixOS adapter uses fixed service names.
The `searxng-aspen1` inventory instance assigns this service to Aspen1.
Its private HTTPS URL is `https://aspen1.bison-tailor.ts.net/`.
The root-owned `searxng-serve.service` maintains the Tailscale Serve mapping. Tailscale Funnel is not enabled.
The host configuration trusts only loopback reverse proxies.
To remove this endpoint, remove the host unit and disable its specific Serve mapping with `tailscale serve --https=443 off`.

For direct Tailnet access, set `bindAddress` to the machine's Tailnet IP and set `openFirewall = true`.
The firewall rule applies only to `firewallInterface`, which defaults to `tailscale0`.
The service provides neither TLS nor user authentication.
Public access requires a separate HTTPS reverse proxy and an access policy.
Configure trusted proxies through `services.searx.limiterSettings` in the machine configuration.

HTML and JSON results are enabled by default. Set `enableJson = false` to disable JSON results.
Rate limits are enabled by default through a local Redis service.
Set `limiter = false` to disable both the rate limits and this Redis service.
The `baseUrl` default is `null`, which leaves URL detection to SearXNG.

## Personal Kagi searches

Read [KAGI.md](KAGI.md) for the opt-in session engine, private engine token, and activation procedure.
It uses a personal Kagi subscription session, not the official search API.
Aspen1 enables Kagi for ordinary searches after browser authorization with `kagiDefault = true`.
The private engine token remains required. Other installations keep Kagi disabled in ordinary searches by default.
`kagiHealthCheck = true` adds a daily session canary and Prometheus rules.
The canary makes one Kagi query per day. HTTP availability probes use `/healthz` without a Kagi query.

## Music and video searches

YouTube uses the native `!yt` engine under Videos and Music.
`enableTidal = true` adds private `!tidal` catalog search using Drift's current access token.
Read [TIDAL.md](TIDAL.md) for the shared browser gate, secret import, and token-expiry limitation.

## Developer searches

`enableDeveloperEngines = true` adds GitHub, NixOS options, Home Manager options, and Noogle under **IT**.
Use `!gh`, `!nixopts`, `!hm`, or `!noogle` to select one directly.
Read [DEVELOPERS.md](DEVELOPERS.md) for catalog versions, bounds, and verification.

## Secrets and runtime

Clan generates a private `searxng-<instance>/env-file` with `SEARX_SECRET_KEY`.
Only the variable reference enters the Nix store. The NixOS initialization unit substitutes the secret at runtime.
uWSGI serves HTTP with access logging disabled. Debug mode remains disabled.
Upstream search engines still receive search queries.

After an inventory assignment, generate the machine variables before deployment:

```console
clan vars generate aspen1
```

The HTTP worker runs in `uwsgi.service`. The initialization unit is `searx-init.service`.
With rate limits enabled, the Redis unit is `redis-searx.service`.
After secret rotation, restart `searx-init.service` and then `uwsgi.service`.

## Verification

```console
nix build .#checks.x86_64-linux.searxng-module .#checks.x86_64-linux.module-registry-sync --no-link --option allow-import-from-derivation true
```

The checks cover default and custom configuration, secret references, firewall scope, and rejected inputs.
They do not prove live search results or a machine deployment.
