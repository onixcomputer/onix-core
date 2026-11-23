## Tasks

- [x] [serial] Append the successor RID to the shared public catalog and both governed validators, preserving order, the pilot, the private set and the node identities. r[onix.radicle_source_admission.policy] r[onix.radicle_source_admission.derivation]
- [x] [serial] Move the CI runner to the successor: adapter URL, M″ NAR hash, reviewed commit, lock BLAKE3s, `brittonr` delegate, vendored OnixOS CI policy v2 bytes and BLAKE3; record the guard retirement. r[onix.radicle_ci.configuration]
- [x] [serial] Add typed, reviewed `staticPeers` to the replica and lower the desktop replica to static peers Aspen1 and Aspen3. r[onix.radicle_replica.configuration]
- [x] [parallel] Extend the focused checks with the successor, the historical/current CI split, static-peer positives and negatives. r[onix.radicle_source_admission.validation] r[onix.radicle_replica.configuration.rejected]
- [x] [serial] Run `nix flake check`, the focused Radicle checks and the `aspen1`, `britton-desktop` and `aspen3` toplevels; record exit codes. r[onix.radicle_source_admission.validation]
- [ ] [serial] Compare each host's running system with its candidate and deploy only hosts whose delta is limited to this admission; repair the desktop replica first. r[onix.radicle_source_admission.deployment]
- [ ] [serial] Verify reconcile `added=1` then steady state, storage, adapter `HEAD`/`main` = `9e64b2f429c8f9035a06fe60ace3adbf331c5598` and CI units. r[onix.radicle_source_admission.probes]
- [ ] [serial] Emit `evidence/radicle/bounded-exec-successor-source-admission-v1.{ncl,json,blake3}` with its check, naming the bootstrap profile, plus single-seed outage drills; then accept the specs and archive. r[onix.radicle_source_admission.evidence]

Published to onix-core `main` as `1ccc52aab8a56d9ff84dee057fac90564618d121`
(fast-forward from `a9c647b7`; the push bypassed the required
`buildbot/nix-build` status check, which already fails on `main`). Gates on that
head: Cairn `validate --strict` and the proposal, design and tasks gates exit 0;
eight focused Radicle checks exit 0, while
`radicle-canonical-artifact-source-admission` and
`radicle-durable-file-publication-source-admission` exit 1 identically on
`a9c647b7`; `nix flake check -L --keep-going` exits 1 with exactly the failing
set of `a9c647b7`. The `nixos-aspen1`, `nixos-aspen2`, `nixos-aspen3` and
`nixos-bonsai` toplevels build; `nixos-britton-desktop` fails only through
dependencies identical to base (tt-umd, tt-metal, pyopenjtalk-plus,
linux-6.18.57-modules); `pre-commit` reformats only the base files
`inventory/tags/common/herdr-iroh.nix` and `modules/llm-agents/underclass.ts`.

The deploy tasks stay open, blocked on owner work that is not on `main`:

- Aspen3: a candidate from `main` rolls nixpkgs back from `4fe25e1` to
  `5adc508` and the kernel from 6.18.60 to 6.18.57; the owner must land the
  nixpkgs `4fe25e1` bump (branch `herdr-britton-air`) on `main`.
- Desktop: the candidate closure carries `tt-umd`, `tt-smi` and
  `tt-system-tools` and the same nixpkgs rollback; the owner must land the
  `pkgs/tenstorrent-compat` work and the nixpkgs bump, and runs this deploy.
- Aspen1: runs a system built from the owner's `49f34ffe-dirty` tree; the owner
  must commit and publish that work (including `f82bcd25` and `08f9b24e`) to
  `main`, and runs this deploy.
