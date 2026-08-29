# Profile-bound production shadow

Date: 2026-08-29

## Deployment

The managed Clan update activated closure:

`/nix/store/q89zgccfjbr5r7j4g73x0mi7nfg0v82p-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

The closure uses:

- Kiln `330059df57641300baa6c2ae09fd3a4989018d40`;
- host package `/nix/store/mpwqscmfwqym271f0wi0816xl4b3sc6z-kiln-aspen-host-0.1.0`;
- extension package `/nix/store/g0bhhd3h664x942hqqx48bknbvzs3099-kiln-0.1.0`;
- production Lattice `feb16b911a23e36d22d1359e44a9bc6b692cc98c`;
- a `7,290,000` millisecond callback bound; and
- a `7,068` millisecond observation interval.

Source admission, Lattice, host, and the legacy broker were active. The authority probe returned `PASS`. The host and Lattice sockets had mode `0660`. Their state roots had mode `0700`.

## Retained fifth attempt

Operation `44548a9302505778d3e43384a67be779ffa201e30ba0fea8d23ada664d4b7bf2` stayed `reserved` with no effect or acknowledgement. Its host root is retained at:

`/var/lib/kiln-aspen-radicle-ci/quarantine/profile-drift-host-20260828-44548a93`

The retained operation ledger BLAKE3 is `ef36e8f6e5baf7a42cbad03600af2e5dc2bde4d4db29bdf965541c79a870dc85`. The retained native journal BLAKE3 is `7369f695737790b092ddfea5cafc0a668ff3167c85e2e5af7b82d5dfaf0b8a5f`.

## Sixth shadow

The fresh status-disabled trigger used:

- actor `did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx`;
- before `d88cc41b0145d5dc118a6313054c5d3e66efbe19`;
- after `5f659dce24e13b30e996f0aab3419dac4c21f934`; and
- repository `rad:z3xXXCQXCTquvAawh41YYs8yC8xmk`.

The request started at `00:25:23.539 -0400` and finished at `00:25:37.941 -0400`. The host operation is `1d71cff53769fbd026de3f56455b53b4bbb37fd8a6d9ed062c137f4d6ccb1e19`.

The exact terminal facts are:

- run ID `kiln-aspen-run-95bc8179a0dd3ff4ba736a9de99b32594021df89d7b510e1454b38f011af3477`;
- service receipt `a2f0d0204c38a762d98b0a2b03294e715d7483201636040f9abb04aecff98b24`;
- terminal decision `failed`;
- provider outcome `DomainFailure`;
- provider run `b3:e3c848d3114b14a6c299684832a28ac4b392bcdad8da033fba598a5cae9a743c`;
- report BLAKE3 `2a058ce6f6038cc508f0fcd03230a517dfc8e22f9daa41832d8772cd635f4269`;
- log BLAKE3 `fe4356d1923d8789dfa67cf19b71b9c50fa9a79d105a31a78c836f167af19fd3`; and
- durable operation record BLAKE3 `1e1b383253efa16ac579c1cc1e80d2e5293298e851f2baa5fd42ecbd27afdbef`.

The report and log use mode `0640`, owner `kiln-aspen-ci-lattice`, and group `kiln-aspen-ci-report`. The provider returned exit code `1`. Its log contains the known Seaglass fixed-output hash mismatch for `components-ccdb07f`. The configured hash starts with `z04F`; the observed hash starts with `s9fz`. This is an honest provider-backed CI failure, not an infrastructure failure or false success.

## Exact replay

An immediate replay returned the same run ID and failure in 54 milliseconds. These values did not change:

- report timestamp and BLAKE3;
- log timestamp and BLAKE3;
- Lattice state timestamp;
- operation-ledger timestamp;
- operation revision `5`;
- operation record hash; and
- service receipt.

## Restart recovery

The host restarted in 203 milliseconds. A replay after restart returned the same run ID and receipt in 55 milliseconds. The report, log, Lattice state timestamp, operation revision, and operation record hash did not change. No provider redispatch occurred.

## Stopped backup and restore

The host and Lattice services stopped before backup. The root-only backup is:

`/var/lib/kiln-aspen-radicle-ci/quarantine/verified-shadow-backup-20260829-1d71cff5`

Its core hashes are:

- host operation ledger `2c5b97f9a233870b5a16bb2a4f93f1e20f100c1d9f365496468930e25ee215ce`;
- host native journal `f8e85807dca13a1d614b542d305f29504d0710f592ec14ab3bf7760912b56158`; and
- Lattice state `0375e052762b32e1042b6a5bcc87c85ca2bc5dfed44844adf95c1f651e514442`.

After the outage drill, both roots were restored from this backup. The host returned the same terminal run, record hash, report hash, and log hash.

## Lattice outage and uncertainty

A fresh direct trigger used actor `did:key:z6MkjCqx5ksRqcDeNeuEnz53udbUHebRLHhddCxecWJu9koE` while Lattice was stopped. The adapter exited with code `2` and reported accepted uncertainty for operation `ee2104285baf27a6c395c1be6c97fe6b28b5be3fae6148b26a92ca97bb40bc43`.

The durable record stayed `uncertain` with effect `kiln-aspen-effect-912dfffe7d26562b7cc38a01937d50b9b9c02be52aa2ce6423be0e5650045aa5`. It had no provider observation and no acknowledgement. A repeat returned the same `Unknown` operation. The report file count stayed at two files. No provider report appeared.

After Lattice returned, host restart rejected the native Aspen `Quarantined` phase. The host did not dispatch the effect through the normal path. The retained roots are:

- `/var/lib/kiln-aspen-radicle-ci/quarantine/outage-uncertain-host-20260829-ee210428`;
- `/var/lib/kiln-aspen-radicle-ci/quarantine/outage-uncertain-lattice-20260829-ee210428`.

## Corruption rejection

The stopped live operation ledger changed from BLAKE3 `18d0a553f25ecbc6618c4e6788bc412c9d20390a072df7d7cf02a01c82cd1158` to `c61dd887e5455bb9252e2dc1c7fdb248f9bddc5bf7878570187c16cb4680335a` after a bounded header corruption. Host startup failed with `file is not a database`. The corrupt root is retained at:

`/var/lib/kiln-aspen-radicle-ci/quarantine/corrupt-ledger-host-20260829-1d71cff5`

The verified backup then restored the same terminal operation and report.

## Bounded replay load and teardown

Sixteen direct replays ran with concurrency four. All processes exited with code `0` and named one unique run ID. Report, log, Lattice state, and operation-ledger timestamps did not change. The ledger still held one record at revision `5` with record hash `1e1b383253efa16ac579c1cc1e80d2e5293298e851f2baa5fd42ecbd27afdbef`.

After provider completion and all drills, UID `975` owned only the Lattice service process. No provider, wrapper, Nix build, or descendant process remained.

## Legacy drain boundary

Before the cutover deployment, broker PID `108751` had no adapter child process. UID `989` had no legacy, Aspen, or Nix adapter process. The broker database BLAKE3 was `bc0ca66f537ffaa44cb39f70f650dbeb4d79bcd7773948072f62e3aa413637b9`. It held zero queued events and four retained runs.

Stopping the broker did not change the database hash or counts. The broker remained inactive at the deployment boundary.

## Non-claims

This evidence proves one bounded local shadow, exact local replay, fail-closed outage and corruption handling, one local backup restore, and an empty local broker queue boundary. It does not prove CI correctness, source trust, host sandboxing, global durability, distributed exactly-once execution, production availability, broker cutover, or release eligibility.
