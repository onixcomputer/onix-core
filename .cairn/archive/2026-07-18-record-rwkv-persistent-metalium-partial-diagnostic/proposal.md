# Proposal: Record the persistent Metalium partial diagnostic

## Why

The single approved persistent Metalium attempt was consumed by pueue task `281` and terminated without retry. One physical DecodeL workload was committed, but Metalium logger bytes were emitted on the child stdout protocol before the canonical response frame, so the host rejected the first response magic. Ownership, HTTP health, rollback state, and board health recovered safely. This terminal result must be preserved without upgrading it into numerical or cross-token success.

## What changes

- Preserve the exact terminal evidence from `/var/tmp/rwkv-ttwkv7-persistent-device-3` in a dedicated fixture excluded from formatting.
- Add a pure Rust evidence checker that proves the exact one-request/one-corrupted-response transcript structure, canonical response offset, finite complete raw output, finite partial post-state, Inspector workload commit, terminal classification, and safe restoration.
- Add a dedicated Nix check with whole-file BLAKE3 authority and positive/negative mutation cases while keeping physical evidence out of the ordinary runtime closure.
- Record the exact narrow claim and non-claims; task `281` is terminal and cannot be retried or reused.
