# Live verified-PR pilot (Kiln #49)

Local NixOS guests on the operator workstation (`pilot-vm.{bug,feature}`),
Kiln `09326e92`, Lattice `7fb6dc47`, Cairn `47ea1b86`, OMP `e325ffc7`, model
`opencode-go/deepseek-v4.1-flash`, target `OnixResearch/implementer-sandbox`
at base `f1adb86f6320f2bbb6c02ae077905a6bb8c22955`. Live-worker evidence only:
it does not qualify KVM boot/restore/migration, cross-host serving or the
retained-guest profiles.

## Run 8: both guests opened a verified PR

| | Bug guest (issue #1) | Feature guest (issue #2) |
|---|---|---|
| Guest VM | `/nix/store/ka11srb01s5ns2w180hbay4g1rbbay48-nixos-vm` | `/nix/store/w02xmr2g8ym3k9xrfklgsnr4bjz40jjl-nixos-vm` |
| Stages | 22/22 exit 0 | 22/22 exit 0 |
| Verified candidate commit | `86e1b3e86de2951840193da4692c1c86765a8a93` | `1867913168d13e312d67e594cebe394d8fbb74ce` |
| Checks | acceptance, tests, clippy, format pass | acceptance, tests, clippy, format pass |
| PR (open, not merged) | https://github.com/OnixResearch/implementer-sandbox/pull/3 | https://github.com/OnixResearch/implementer-sandbox/pull/4 |
| PR head = verified commit | yes | yes |
| Host slot release | settled | settled |
| Final status | attempts 1, verified 1, published 1, failed 0 | attempts 1, verified 1, published 1, failed 0 |
| OMP usage (tokens total / cost) | 13,370 / $0.001203 | 14,982 / $0.002635 |

Both guest VMs evaluate from this change's composition commit
(`fix(kiln-implementer): carry the pilot from dispatch to a published PR`).
Kiln does not yet record model usage itself: it records `model_requests:
"unknown"`; the token and cost figures come from the OMP event log.

### Files

Per guest (`bug-8/`, `feature-8/`):

- `SUMMARY.txt`: the run summary written with the bundle.
- `stages/exit-codes.txt`: every stage, its exit code and timing.
- `sent-request.json`: the request Kiln sent Lattice (with the budget `lineage`).
- `verification-receipt.json`, `verification-handoff.json`: Kiln's verification.
- `publication-receipt.json`, `gh-pr-<n>.json`: the publication and the PR as GitHub reports it.
- `omp-usage-summary.json`: tokens and cost summed from the OMP event log.
- `release-and-status.txt`: the host-owner release receipt, admission status and final status.
- `kiln-pilot-evidence-*.files.b3`: the in-guest BLAKE3 manifest of the full evidence bundle (66 files).
- `kiln-pilot-evidence-*.tar.gz.b3`: the BLAKE3 hash of that bundle.

Bundle hashes (BLAKE3):

- bug: `53145763b2191c4516594a61dac0469c2aabfecb0c4008beab0235859ae892e9`
- feature: `b770ee4a7ffff88465388fbe17c33b93188ce5baf19982e6dd0c88fa06d9ff9e`

The bundles themselves, the raw OMP event logs, guest journals and console
logs are kept by the operator and are not committed. `SUMMARY.txt` names some
of those files.

## Earlier runs

- **Run 6** (bug guest, Kiln `91ad7301`, VM
  `/nix/store/sqnbpdkxw1akjysb02ymfrb8pikx3x09-nixos-vm`): stopped at stage 13,
  `export-candidate`, exit 1. The worker had produced the correct edit. Lattice
  refused recovery: "request differs from persisted execution intent".
  Cause: export passed the sealed `attempt.json`, but with a host-owner
  reservation Kiln had sent Lattice that request plus a budget `lineage`.
  Fix: export and cancel resolve the recorded request through Kiln
  `09326e92`'s `kiln-lattice-dispatch --sent-request true`, in commits d1e3140b
  (`build(kiln-implementer): repin Kiln to 09326e92`) and 44a41630
  (`fix(kiln-implementer): carry the pilot from dispatch to a published PR`).
  Nothing was written to GitHub.
- **Run 7** (bug guest, Kiln `09326e92`, VM
  `/nix/store/7268ns3s9vnqcdy2z8y9vh40w2z6vq9y-nixos-vm`): stages 1-18 passed,
  including verification; stopped at stage 19, `publish`, exit 1, with
  `github_publication_remote_mismatch` before any network call. Cause: the
  publication remote used `OnixResearch/implementer-sandbox`, while Kiln
  compares it exactly with `https://github.com/<owner>/<name>.git` built from
  the lowercase durable key `onixresearch/implementer-sandbox`. Fix: the
  remote derives from the durable key, and `build_pilot.py` checks it, in
  commit 44a41630 (`fix(kiln-implementer): carry the pilot from dispatch to a
  published PR`). Nothing was written to GitHub.
