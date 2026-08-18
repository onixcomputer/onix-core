# Tasks

- [x] [serial] Add typed CI bot/runner settings, exact-RID admission, and positive/negative Nickel fixtures. r[onix.radicle_ci.configuration]
- [x] [serial] Implement and test the pure event, lock-identity, deduplication, observation, and receipt core. r[onix.radicle_ci.admission]
- [x] [serial] Implement the thin scanner, exact-object exporter, bounded-exec runner, isolated local Nix store, and status publisher shells. r[onix.radicle_ci.execution]
- [x] [serial] Lower separate bot and runner users, state, credentials, spools, hardening, timers, and monitoring onto Aspen1. r[onix.radicle_ci.isolation]
- [x] [parallel] Add package, module, authority, timeout, output-flood, stale-object, changed-lock, retry, and restart-deduplication checks. r[onix.radicle_ci.validation]
- [x] [serial] Generate and pin the CI bot identity; prove it is not a delegate and production seed policy remains exact. r[onix.radicle_ci.identity]
- [x] [serial] Build and deploy Aspen1, then verify services, restart continuity, filesystem/credential isolation, and unchanged public/native forge behavior. r[onix.radicle_ci.deployment]
- [x] [serial] Submit an actual Radicle patch, observe its exact bounded Nix job and bot status comment, and run negative authority probes. r[onix.radicle_ci.drill]
- [x] [serial] Emit a typed BLAKE3 deployment receipt, run focused Nix/Cairn checks, sync the accepted spec, and archive only at the proved claim boundary. r[onix.radicle_ci.evidence]
