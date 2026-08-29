# Tasks: Fix broker announce namespace

- [ ] [serial] Add the announce namespace patch to the machine configuration and pin the patched broker package. r[onix.radicle_ci.broker_announce_namespace]
- [ ] [serial] Assert the announce namespace patch in the machine evaluation checks. r[onix.radicle_ci.broker_announce_namespace.pinned]
- [ ] [serial] Validate strict Cairn and the focused Nix checks, deploy, and verify one live event announces without a JobFailure. r[onix.radicle_ci.broker_announce_namespace]
- [ ] [serial] Sync and archive after the live verification passes. r[onix.radicle_ci.broker_announce_namespace]
