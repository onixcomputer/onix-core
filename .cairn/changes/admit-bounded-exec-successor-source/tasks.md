## Tasks

- [x] [serial] Append the successor RID to the shared public catalog and both governed validators, preserving order, the pilot, the private set and the node identities. r[onix.radicle_source_admission.policy] r[onix.radicle_source_admission.derivation]
- [x] [serial] Move the CI runner to the successor: adapter URL, M″ NAR hash, reviewed commit, lock BLAKE3s, `brittonr` delegate, vendored OnixOS CI policy v2 bytes and BLAKE3; record the guard retirement. r[onix.radicle_ci.configuration]
- [x] [serial] Add typed, reviewed `staticPeers` to the replica and lower the desktop replica to static peers Aspen1 and Aspen3. r[onix.radicle_replica.configuration]
- [x] [parallel] Extend the focused checks with the successor, the historical/current CI split, static-peer positives and negatives. r[onix.radicle_source_admission.validation] r[onix.radicle_replica.configuration.rejected]
- [ ] [serial] Run `nix flake check`, the focused Radicle checks and the `aspen1`, `britton-desktop` and `aspen3` toplevels; record exit codes. r[onix.radicle_source_admission.validation]
- [ ] [serial] Compare each host's running system with its candidate and deploy only hosts whose delta is limited to this admission; repair the desktop replica first. r[onix.radicle_source_admission.deployment]
- [ ] [serial] Verify reconcile `added=1` then steady state, storage, adapter `HEAD`/`main` = `9e64b2f429c8f9035a06fe60ace3adbf331c5598` and CI units. r[onix.radicle_source_admission.probes]
- [ ] [serial] Emit `evidence/radicle/bounded-exec-successor-source-admission-v1.{ncl,json,blake3}` with its check, naming the bootstrap profile, plus single-seed outage drills; then accept the specs and archive. r[onix.radicle_source_admission.evidence]
