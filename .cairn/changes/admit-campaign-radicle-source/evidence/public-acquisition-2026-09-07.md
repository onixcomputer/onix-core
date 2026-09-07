# Public Campaign acquisition

The user explicitly authorized public access to Campaign and its repository history on 2026-09-07.

`rad publish rad:z2scC9MCm3pxk9mX4FEidRKabQ5LN` completed. The identity now declares public visibility. No other repository visibility changed.

## Native replication

Aspen1 fetched Campaign through Radicle with `scope=all` and the `parent` signed-reference floor. The initial CLI wait reached its deadline, but the node completed replication afterward. The later storage checks establish success, not the timed-out command.

Aspen1's native repository contains commit `e23e3edf1dc6a8c612a4ea33a3b805bda1173e3b`. Its strict Git object check passed. Its Git archive has BLAKE3:

```text
78136b386be193f30ee75150eaf56f2576413cb70c4fc0b304983187008480f1
```

The service-owned reconciler subsequently returned `Result=success` and `ExecMainStatus=0`.

## Fresh HTTPS acquisition

A new empty bare repository fetched that exact commit from:

```text
https://git.onix.computer/z2scC9MCm3pxk9mX4FEidRKabQ5LN.git
```

The strict Git object check passed. The fetched archive matches the local reference byte for byte and has the same BLAKE3 identity. The bare repository has no branch references, so Git reports the fetched commit as dangling. This is not an object-integrity error.

## Negative controls

| Probe | HTTP status |
|---|---|
| Synthetic undeclared RID | 404 |
| Receive-pack discovery | 404 |
| Receive-pack POST with no update command | 404 |
| Campaign upload-pack discovery | 200 |

The previous private-source and HTTP 500 blockers are resolved. These observations do not prove fleet deployment, full lifecycle completion, or ChaosControl adoption.

Retained operator evidence includes `campaign-public-identity.json`, `campaign-public-native-fetch.log`, `campaign-public-native-verified.log`, `campaign-public-http-probes.log`, and `campaign-public-https.tar`.
