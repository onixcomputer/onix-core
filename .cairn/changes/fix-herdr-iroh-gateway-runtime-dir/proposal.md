## Why

The herdr-iroh saved-machine gateway forwards calls by running
`herdr --machine <label>`, which runs ssh as `brittonr`. That user's ssh
config, from the yubikey-agent Home Manager profile, contains
`IdentityAgent ${XDG_RUNTIME_DIR}/yubikey-agent/yubikey-agent.sock`. The relay
is a system unit whose environment has no `XDG_RUNTIME_DIR`, so ssh stops with
`Invalid environment expansion ${XDG_RUNTIME_DIR}` and every forwarded call
fails. On 2026-11-08 Grok's pings to britton-desktop, cproof-brittonr and
instantfill-vm through aspen3's gateway reported that error, while direct
herdr access worked.

## What Changes

- Set `XDG_RUNTIME_DIR` on `herdr-iroh.service` to the service user's runtime
  directory, `/run/user/<uid>`, derived from `users.users.<user>.uid`.
- Rebuild britton-desktop and aspen3 from their recorded deployed source with
  only this change, and switch only after `diff-closures` and `dry-activate`
  show the relay as the only restarted unit.

## Impact

The relay restarts with the same endpoint, key and allowlist. ssh started by
the gateway reads the same config as `brittonr`'s login sessions and reaches
the yubikey-agent socket when that agent runs. `brittonr` lingers on both
hosts, so the directory exists without a login session.

## Affected Specs

- `herdr-saved-machine-gateway`: the gateway's ssh must run with the user's
  runtime directory.
