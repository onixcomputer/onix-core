# Aspen1 Radicle CI deployment and drills — 2026-07-25

## Accepted deployment

- Host: `aspen1` via `root@aspen1.local` with strict SSH host-key checking.
- System closure: `/nix/store/icv59w4s3wzlqfg1m26j2wp7x84xb6vl-nixos-system-aspen1-26.11.20260629.7a1a647`.
- Runner: `/nix/store/kcv5lb5ddxrc7kawra0yx8l38m780dm8-radicle-ci-runner-0.1.0`.
- Sync shell: `/nix/store/dwx9gffp8vp4fqvs32nl5ggpb5ir5vzb-radicle-ci-sync`.
- Portable policy BLAKE3: `091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740`.
- Final deployment receipt BLAKE3: `d0a62eb441237aeb327774328aac5f1fe32005322911a72ee5f7ad4ce5fb7c3e`.
- Bounded Exec revision: `29dac88ecded94457572db3fdfaaaab95fa91525`.
- Bot node ID: `z6MknopLULJensBT5KGkC8h9KaHTNY5muZ9UffqroErX7Rni`.
- Bot fingerprint: `SHA256:U4XxEymH9bpdWtN3Yl7ugkOn+Io1OrQ6H2UjkZC9Rg0`.
- The identity prerequisite verified private/public pairing, fingerprint, node ID, non-delegate status, ownership, and modes before node start.
- Bot and production policies each listed only `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo`; both retained default-block configuration.

## Exact patch execution and status

The real docs-only patch was authored outside the bot profile and replicated through Radicle:

- Patch/revision: `fd413bad04e5a622fbc27da67588eea4a8c7e814`.
- Base: `29dac88ecded94457572db3fdfaaaab95fa91525`.
- Exact object: `1baa4f552ae55923b025d99d08073286158836be`.
- Source archive BLAKE3: `705919adac9805963d8d4b25f3d3f6cf19a325d3a17b80b367e59dea40d56f68`.
- Job: `ffaaabbb76f5d54c48dc5c847bbf2ee9cd1513e70af3a29867be212c3be77a90`.
- Final disposition: `succeeded`, exit code `0`.
- Event BLAKE3: `25fb18faa9dc7c3fc773994a127b2c15f3c10cae8defc4ab6173273751d70b72`.
- Result BLAKE3: `f458e88b37a9dff3543b60e58154d45ea1cfd715df0662689942748c7945dc3c`.
- Raw artifact manifest BLAKE3: `9046a67eee06c634ded25cc938acc6f076693e056a0a6fe42be9e026e06560cb`; tree-formatted checked-in copy BLAKE3: `747e1be814f6d0a16f7640d0df2890e2e07b416c726fb3b04558249f13b34ae5`.
- Status operation: `53db765918597276cca4364310d3c622aa85c600`, authored by the non-delegate bot.
- The final comment states `Succeeded`, the exact job/object/artifact identities, and that the result is a bounded observation rather than merge or release approval.

Four earlier bounded `ExitFailed` observations and the final successful observation remain in the bot COB history. The successful result replaced the retry artifact only after exact-event replay; no failure gained additional authority.

After the reviewed patch reached two delegate signatures, the scanner observed the same exact object as canonical branch job `9c090732a5248912f7e42c6c26889804545df382d31a5955584c3ddf839cc4ac`. It succeeded with event BLAKE3 `38080e0b11fc0b58b11e4bae79822d03a64eda17947c84af2237fcf6e851ef8a`, result BLAKE3 `790e3a4cb3044757cf7373839f558accb7b3ab28087ad96d75d5abe382328e42`, and artifact BLAKE3 `2633b4fa836e3ab876ab379a53fbb0bdd2d50779fb045caf30582b5eccf25249`.

## Independent review and canonical convergence

Bonsai delegate `z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE` independently accepted the exact revision in operation `71ee3f83fbb4fa436aee07f311dd7519ee177cde`. Its encrypted profile was decrypted only under `/dev/shm`; cleanup traps removed plaintext key and profile material. Duplicate live-node protection prevented a second Bonsai network session, so review and `main` signing were performed offline over copied public storage. Only Bonsai's signed public namespace was exported and imported.

The author and Bonsai delegate then signed `main` at `1baa4f552ae55923b025d99d08073286158836be`. The third delegate remained at the prior commit. The two-of-three result was verified on Aspen storage, desktop storage, and public HTTPS. Direct namespace transfer to the two seeds preserved the signed refs while root operator code updated each derived top-level ref only after exact author/reviewer sigref and object checks. This was operator recovery for an offline delegate, not seed or CI canonical authority.

## Restart and deduplication

The first controlled restart exposed a readiness race: sync began before the bot control socket was bound. Revision `45c99c864a4610ae7f84cdb79e87fcafe779f92f` added a bounded 60-attempt, one-second socket wait and static checks. After redeployment, the exact failed ordering passed.

Final before/after observations on the accepted closure:

- Patch result mtime: `1785009233` → `1785009233`.
- Patch status operations: `5` → `5`.
- Successful status comments: `1` → `1`.
- Durable ledger entries: `3` → `3`.
- Sync, scan, runner, and publisher results: `success`.
- Runner and publisher reported idle; no event, build, artifact, or comment was duplicated.

## Deployed negative probes

`radicle-ci-isolation-probe.service` succeeded with raw-observation BLAKE3 `f0d5ce42f5d3ff96ba6529ae7a7cbbf446843fddb49db1b4d843a15dbd4710bb`. The tree-formatted checked-in copy has BLAKE3 `19b010f00b44ca1db89ea93983d8b35b3be2f7e5c276c8b9416d687f5b7dbbb5`:

- runner state positive control: allowed;
- production seed network: denied;
- `/run/secrets`, production Radicle state, bot state, root/home, and SSH paths: denied;
- canonical-ref and seed-policy mutation: unavailable because production storage is denied;
- cache write: unavailable under `ProtectSystem=strict`;
- deployment and secret access: unavailable because `/run/secrets` is denied.

`radicle-ci-bounds-probe.service` succeeded under the same credentialless private-network runner boundary with raw-observation BLAKE3 `51d251ee90e5b34213d43f8c930a1591579dec1d5d2b38f91f8f4fda2af6aca0`. The tree-formatted checked-in copy has BLAKE3 `67404cfad743ffcb7dd2201e3c1ad285ac189a586eafd3dccec0ebb226dd598c`:

- timeout child: `timed_out-and-torn-down`;
- stdout flood: `output_limit_exceeded-and-truncated`;
- retained limit: `1024` bytes;
- observed output: `2048` bytes;
- credentials: none.

The deployed runner unit had no credential directives, `PrivateNetwork=yes`, only `AF_UNIX`, an empty capability bounding set, `ProtectSystem=strict`, `MemoryMax=8589934592`, and `TasksMax=256`. Its inaccessible paths included production Radicle state, bot state, secrets, homes, SSH state, Harmonia, and the host Nix daemon socket. Only exchange, runner, and artifact state were writable; the private rooted Nix store and fixed `/bin/sh` were the only binds.

## Monitoring and retained behavior

Prometheus, systemd-exporter, the bot node, and the sync timer were active. The `RadicleCiUnitFailed` rule remained loaded. Public upload-pack-only HTTPS resolved `refs/heads/main` to `1baa4f552ae55923b025d99d08073286158836be`; Aspen and desktop native storage matched. The production seed identity and one-RID policy remained unchanged.

## Claim boundary

This evidence proves only the recorded exact-object CI observations, process/output bounds, service isolation observations, non-delegate status authority, restart deduplication, and two-delegate signed convergence. It does not prove source or Nix correctness, host sandbox correctness, artifact durability, mandatory-CI merge enforcement, private-repository confidentiality, automatic failover, live delegate replacement, geographic/building-power independence, whole-stack GitHub independence, or release readiness.
