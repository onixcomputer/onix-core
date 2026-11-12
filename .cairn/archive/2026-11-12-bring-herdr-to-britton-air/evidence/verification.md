# britton-air Herdr verification

## Versions

- `herdr 0.9.3` from `/run/current-system/sw/bin/herdr`
- `herdr-app 0.1.14` from `/etc/profiles/per-user/brittonr/bin/herdr-app`
- System generation: `/nix/store/jjygp79jpxr4dm7wlb9rr807islrippd-darwin-system-26.11.bb0b90d`
- onixpkgs: `de18d43acc410a38a2d5eee1e1c5dd8648b4db4e`

## Plugins

`herdr plugin list` reports seven enabled plugins:
`dev.herdr.pueue`, `dutifuldev.ghzinga`, `herdr-file-viewer`, `mirror`,
`nathanflurry.jj-workspace`, `persiyanov.reviewr`, `vim-herdr-navigation`.
`herdr.collie` is intentionally absent on Darwin.

## Config

- `~/.config/herdr/config.toml` is a Home Manager link.
- SHA-256 `3896e0418a91c1556717898b13e24ee20720b10b9de6eb3291130b1ad189e251`,
  identical to aspen3's rendered config.

## Relay

- `launchctl list` reports `org.nix-community.home.herdr-iroh` with PID and
  exit status 0.
- `/Users/brittonr/Library/Logs/herdr-iroh.log`:
  `gateway=true`, `peers=1`, `relays=true`, listener ready with endpoint
  `892127597af970511155b881294d7e3aed9a9cd9813225f6b0d48cbd5db4de10`.

## Saved machines

`herdr machine list` matches aspen3:

```text
5d07ba066a1dec08c59e51d44b61b5d6  britton-desktop    britton-desktop              default enabled
e613f13477712171eea1c208e8230b55  cproof-brittonr    cproof-brittonr              default enabled
4326a76785bae7240f5e3575596ddb66  instantfill-vm     britton@instantfill-vm       default enabled
```

`herdr machine status`: `britton-desktop` reachable; `cproof-brittonr` and
`instantfill-vm` report DNS/network errors because the Mac is off-network and
the VM is tailnet-only while britton-air has no Tailscale.
