# Kiln-on-Aspen private canary

This Clan module deploys one separate, operator-controlled Kiln canary on `britton-desktop`.

It does not modify the existing Seaglass broker route. No Radicle broker event targets the canary socket.

## Composition

The module starts two long-lived services:

- `kiln-aspen-canary-lattice.service` owns the Lattice store and workflow socket.
- `kiln-aspen-canary-host.service` owns the Aspen host state and Kiln service socket.

The services use distinct Unix users and state roots. They share one socket group and one private runtime directory.

The Lattice server connection budget covers one dispatch and every admitted poll for each bounded host request. The typed profile rejects a budget above Lattice's contract limit.

Before a service restart, separate guarded steps remove only that service's stale Unix socket. Each guard fails if its exact path contains another file type, and cross-socket checks keep the paths separate.

The Aspen host executes `kiln-aspen-extension` through Aspen's bounded native-process port. Provider effects use Lattice's durable workflow exchange.

## Reviewed cohort

The module pins these revisions through Nix:

- Aspen effect materialization: `22f8ded26ca1907c29948e08b53f35df23080733`;
- Kiln deployable host: `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`;
- Kiln hosted protocol: `42eabcb21385a436ddc044fb7034b8cdaec7b8a0`;
- Lattice application runtime: `c513d94d89e901ffa56ae67f375f973e55958e42`;
- Lattice workflow contract: `70496e67c7fd4a8b05914161a8e09de2759bebc8`; and
- Bounded Exec: `29dac88ecded94457572db3fdfaaaab95fa91525`.

The final Onix Core lock also binds the Kiln commit that contains the deployable host package.

## Profiles

Human-authored Nickel files define the Lattice app config, Lattice route, workflow, Radicle trigger profile, and module settings.

The route binds these exact identities:

- capability profile: `b3:67f30a749eaa91b56a5a0e42873c9b13968ff92ae87f577c6f36041f4a722cb5`;
- request graph: `b3:a5af82f6dc0f5b094624022825ba048775cc4892bfdd12473bb57945e8745426`; and
- workflow revision: `b3:1377fce07f3426f87ab7c61d6a716d3f1fc95be71f91ab87699e13f56dbd35b3`.

A changed profile or workflow fails before the provider effect starts.

## Validation

Run the focused checks before deployment:

```console
nix build path:$PWD#checks.x86_64-linux.kiln-aspen-canary-profiles --no-link -L
nix build path:$PWD#checks.x86_64-linux.kiln-aspen-canary-module --no-link -L
nix eval path:$PWD#nixosConfigurations.britton-desktop.config.system.build.toplevel.drvPath
nix run path:/home/brittonr/git/cairn#cairn -- \
  validate \
  --root "$PWD" \
  --policy /home/brittonr/git/cairn/cairn-policy/generated/cairn-policy.json
```

## Deployment

Deploy only after all focused checks pass:

```console
NIX_CONFIG=$'min-free = 0\nmax-free = 0\nbuilders =\n' \
  nix develop path:$PWD#minimal -c clan machines update britton-desktop \
    --build-host localhost \
    --upload-inputs
```

Inspect both services:

```console
systemctl status kiln-aspen-canary-lattice.service
systemctl status kiln-aspen-canary-host.service
```

## Operator drills

The drill units have no `wantedBy` target. Only an operator can start them.

Run one accepted trigger:

```console
systemctl start kiln-aspen-canary-accepted.service
journalctl -u kiln-aspen-canary-accepted.service --no-pager
```

Run one denied trigger. The callback must release no Lattice effect:

```console
systemctl start kiln-aspen-canary-rejected.service
journalctl -u kiln-aspen-canary-rejected.service --no-pager
```

Prove a missing Aspen socket fails without fallback:

```console
systemctl start kiln-aspen-canary-unavailable.service
journalctl -u kiln-aspen-canary-unavailable.service --no-pager
```

Prove disconnect after provider request write remains `Unknown`:

```console
systemctl start kiln-aspen-canary-uncertain.service
journalctl -u kiln-aspen-canary-uncertain.service --no-pager
```

The uncertainty drill temporarily renames the live Lattice socket. A bounded local `socat` endpoint reads one complete request and closes without a response. The script restores the original live socket before it exits.

Exercise explicit rollback. This command selects Lattice directly; it is not automatic fallback:

```console
systemctl start kiln-aspen-canary-rollback-lattice.service
journalctl -u kiln-aspen-canary-rollback-lattice.service --no-pager
```

Bounded receipts are stored under `/var/lib/kiln-aspen-canary/host/receipts`.

## Stop and rollback

Stop the canary without changing the existing CI route:

```console
systemctl stop kiln-aspen-canary-host.service
systemctl stop kiln-aspen-canary-lattice.service
```

Set `enable = false` in the canary instance and deploy again to remove the services. Do not add an automatic runtime fallback.

## Non-claims

This canary proves only private, local, process-scoped observations for the exact deployed cohort.

It does not prove production availability, global durability, CI correctness, workflow correctness, host sandboxing, credential freshness, external effect success, or release eligibility.
