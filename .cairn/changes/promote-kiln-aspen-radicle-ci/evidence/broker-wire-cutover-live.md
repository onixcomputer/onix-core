# Broker wire cutover live evidence

Date: 2026-08-29

## Deployed cohort

The managed Clan update built locally because the remote builder cannot fetch Kiln's private Cargo dependency. The active closure is:

`/nix/store/rmh24zzr047wxx5pwbwqa1jwa7y56h7x-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

It pins Kiln `8c9338e5c10a0e16ee3042d11583ccccf6efe7e9` and Onix commit `10b7a2d0`. The broker adapter is `/nix/store/wb8508dg96k394v61gagfzsmqa69i2gf-kiln-aspen-ci-adapter/bin/kiln-aspen-ci-adapter`. Its environment is empty.

The first switch exposed an old Aspen `Quarantined` phase. That host root is retained at `precutover-quarantined-host-20260829-yskn8gb4`. Its file-manifest BLAKE3 is `60efb12787e9c62e362d75e44902b4fe4850cec7a1eadd0ca3d76bf345d93394`. The active host started from a new empty root.

## Retained source failures

A normal event for `fd537dab63ec26f2355e16bfa33d691e0cfa625f` reached the provider before the commit was visible. Report run `b3:d5ef57738e9ac6d55c21e2d9474a7c3bdf17af3fd1c577b83a9438280b4260bc` is retained under `stale-source-report-20260829-d5ef5773`. Its report and log BLAKE3 values are `5766c11efa4f8ba1f2efdc2817b493aff6ede6bd738a93dd6e70c5ffc0b34701` and `9f1c6b5775335931e50d5b7056594ca8abc1fc23f2b62571631b475f66a43503`.

A ten-second source wait for `1a08d415d1041bd08cf6992d3ec4302ca38180c1` expired. Report run `b3:8ad2d76df2920d6e8b4bd8c4982aa863ba461b0ce98144f21d6abba1b56dad71` is retained under `source-wait-bound-report-20260829-8ad2d76d`. Its report and log BLAKE3 values are `3bb6ae07c6e6d29aab80ff5903f9dc3bc2d847464f0d7be3a97209f0c4cf9126` and `0f4f11645e29f233becc82587be19a4a80b0250fc989f13b353b057e77816d7d`.

A sixty-second wait for `d77c989ab4caca88fd861e7f864bd2d7b19c1556` also expired. The object existed, but new Git pack files had ACL entries masked to no access. Report run `b3:649878d2148060e4309484ced5041d9001ec5f1d537184c9441471e1102c9128` is retained under `source-acl-report-20260829-649878d2`. Its report and log BLAKE3 values are `61b98c1865fd5915845d322a88ac7733596edae95f4065e89669e95e52b4fbdb` and `1f8769bf5c64459b13a200b6d8b7ee8fbfc52fe06512589fd472770f8b00933c`.

Each failed host and Lattice root is retained under the matching root-only quarantine name. None was reused for the final run.

## Automatic source admission

The final test did not pre-stage commit `b3ae3847242af5b8a1c7da0df488ccb9a050d809` in managed storage. The source-refresh path observed the pack or master-reference change. Its oneshot ran from `03:07:01.959972` to `03:07:02.013034` and returned success. The Lattice user then admitted the exact commit through its bound source view.

The provider log contains no `not our ref` or source-readiness diagnostic. It reached Nix and reported the known `components-ccdb07f` fixed-output mismatch:

- specified: `sha256-z04Fq35KCS2LriSr85kqTpMv5LX3b/QPbvEl2jWxnR0=`;
- observed: `sha256-s9fz06oVni9eSSmYbPzsDuJdKmqOT8il0DcTjdnZMwU=`.

## Final real event

The default-branch event started broker run `fee612ad-fe27-44a3-add4-a4dceaccbb09`. It produced:

- Kiln run `kiln-aspen-run-3c99b17178e0644b00af32da98a6b8e43969b490eafc4e48ee919b3fa96b0605`;
- Aspen operation `90f2e26bf144a436608727482afd9b9dae18a2236d5822d13b7e614f12537938`;
- operation record BLAKE3 `b909a69f98ff7cd6c31d8c1f8afc03ebc909c022015e6109f927c2cabcffc468` at revision `5`;
- service receipt `e170f97f0fd3fa6745844cb802207a13250deddac913d860d95cce4cdec1276b`;
- callback receipt `ce98f0a3e85ab53deb03e773b21fa0389a43a57623d5185c66ee72fb2fefb255`;
- provider execution `b3:d304cc4280651b8cfff1fa0cb8f9b9c660ff2fdf1347208fc196e174425f722a`;
- provider report run `b3:878aa29f23b1750b882a66ae29570adc323e8ff55e053a3820bf242c5baa169a`.

The terminal decision is `failed`, provider outcome is `DomainFailure`, and provider exit code is `1`. This is an honest Seaglass build failure.

The report and log use mode `0640`, owner `kiln-aspen-ci-lattice`, and group `kiln-aspen-ci-report`. Their BLAKE3 values are:

- report: `3541538477dfc0bbed432862c8015f05b757781ac03752d870c6e449b85bfa4f`;
- log: `9110231cf0b3b6cee7b7cd80364cc7555bd7aa8467e9c403d6913059c38b3a62`.

The report server returned the exact report bytes on loopback with the same BLAKE3.

## Replay and restart

An immediate replay completed in `10,683,275` nanoseconds. A replay after host restart completed in `16,873,415` nanoseconds. Both returned the same Kiln run and failure.

Report, log, Lattice state, operation record hash, operation revision, and service receipt did not change. The SQLite container bytes changed when the database reopened, but the canonical operation record did not. No second provider report or dispatch appeared.

After teardown, UID `975` owned only the Lattice service process. The broker queue held zero events.

## Radicle status and health

The broker created job `235f50cb19802b8a8c9f316ed42d21a8415d754f`. Local status ref tip `2bf89e33469ee37a2fe8c0d021af132b76371946` contains `Finished` with reason `Failed` and broker run `fee612ad-fe27-44a3-add4-a4dceaccbb09`.

Network announcement returned `no refs were announced`. This evidence proves local status persistence only. It does not prove remote status propagation.

The broker, host, Lattice, source admission, source-refresh path, and report server are active. The authority probe returned `PASS`. State roots use mode `0700`, sockets use `0660`, and the report uses `0640`. The broker queue is empty with ten retained runs.

## Non-claims

This evidence proves one bounded machine-local cutover event, automatic source ACL refresh, provider-backed failure, exact replay, restart replay, report serving, local status persistence, and teardown. It does not prove CI correctness, source trust, external provider truth, remote status propagation, global durability, distributed exactly-once execution, production availability, host sandbox correctness, or release eligibility.
