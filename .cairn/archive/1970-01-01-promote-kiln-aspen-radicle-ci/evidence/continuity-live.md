# Broker continuity live event

Date: 2026-08-28

## Deployment

Onix activated closure `/nix/store/qmzvmq7njifhzmy4dc9zvzns94b3b161-nixos-system-britton-desktop-26.11.20260819.afe3d8a` from commit `955ab0b5da74435012f3e50d1dad2c4f34516301`.

Activation retained the known `datapool/kache-nix` and `/var/cache/kache-nix` quota warnings. The retry confirmed that the closure was active. `radicle-ci-broker.service` returned to `active`.

## Exact event

The authoring node fast-forwarded private Seaglass `master` from `6da5fa38010d0f18b5ec7435d602bd4cb8c98fbe` to `5f659dce24e13b30e996f0aab3419dac4c21f934`. The managed replication unit fetched the update from the private authoring node.

The broker admitted the exact default-branch event as queue item `f9bb6a07-f5da-4b8e-b74a-27572fccc255`. Broker run `12f76ac4-c8a7-483f-a849-208fa957bcc5` invoked:

`/nix/store/sq38b7ya66wff7c05k4xqhi87xdf16m1-kiln-0.1.0/bin/kiln-adapter-radicle`

That path is the separately pinned legacy Kiln cohort. The adapter emitted the historical Defelo start and finish protocol, exited with status `0`, and retained its report.

## Bounded result

The CI result was `failure`, not false success. Seaglass evaluation reached its real Nix graph and stopped on the existing `components-ccdb07f` fixed-output hash mismatch:

- expected `sha256-z04Fq35KCS2LriSr85kqTpMv5LX3b/QPbvEl2jWxnR0=`;
- observed `sha256-s9fz06oVni9eSSmYbPzsDuJdKmqOT8il0DcTjdnZMwU=`.

The retained log is 50,054 bytes, mode `0600`, and owned by `radicle:radicle`. Its BLAKE3 is `e5ceeee8f23a84dd1b279562e8551a6e98eb5fa0b9973e4e93e48f5ba4ca2308`.

This evidence proves restored broker-to-legacy-adapter compatibility and exact event handling. It does not prove a passing Seaglass revision, Aspen production routing, or release eligibility.
