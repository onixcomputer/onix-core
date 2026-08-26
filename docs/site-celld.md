# Site Celld fleet

The Site fleet serves the generated Aspen documentation on two private Tailnet endpoints.

| Host | RustFS endpoint | Site endpoint |
|---|---|---|
| aspen3 | `http://100.108.13.4:39000` | `http://100.108.13.4:32110` |
| britton-desktop | `http://100.110.43.11:39000` | `http://100.110.43.11:32110` |

The fleet uses these isolated resources:

- bucket: `onix-site-celld`
- access key: `celld-site`
- systemd service: `celld-site.service`
- public port: `32110`
- internal port: `32111`
- state directory: `/var/lib/celld-site`

The `celld-lab` fleet remains separate. It continues to use service `celld.service`, bucket `onix-celld-lab`, and ports `39200` and `39201`.

## Publisher credential

Clan generates one bucket-scoped credential. The Celld service reads the environment file as user `celld-site`. User `brittonr` receives the same secret as standard AWS environment variables:

```text
/run/secrets/vars/shared/celld-site-celld/publisher-aws-env
```

The file has mode `0400`. It does not contain RustFS administrator authority.

Set the file for one command. Do not replace the user's default AWS configuration:

```sh
(
  set -a
  . /run/secrets/vars/shared/celld-site-celld/publisher-aws-env
  set +a
  site celld-deploy \
    --project-name aspen-docs \
    --compatibility-date 2026-08-26 \
    --bucket s3://onix-site-celld \
    --endpoint http://100.110.43.11:39000 \
    --write
)
```

Run the same command without `--write` first.

## Activation

Celld `0.3.0` reads the active deployment during startup. Restart the two Site units after a successful upload:

```sh
systemctl restart celld-site.service
ssh root@britton-desktop systemctl restart celld-site.service
```

Wait for each health response before the next restart:

```sh
curl --fail --max-time 5 http://100.108.13.4:32110/__celld/health
curl --fail --max-time 5 http://100.110.43.11:32110/__celld/health
```

Then retrieve one expected asset through both endpoints.

## Evidence boundary

An upload receipt proves one RustFS mutation. A health response proves only that one Celld process answered. An asset probe proves only that one endpoint returned the expected bytes at that time.

The endpoints are private. This runbook makes no public Internet, long-duration availability, or node-loss tolerance claim.
