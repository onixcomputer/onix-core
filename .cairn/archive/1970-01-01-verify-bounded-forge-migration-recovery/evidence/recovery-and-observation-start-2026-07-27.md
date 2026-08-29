# Bounded forge recovery and observation start — 2026-07-27

## Checkpoint

The on-demand Aspen Borg job created encrypted `repokey` archive `aspen1-britton-desktop-2026-07-26T20:45:35` in desktop repository `8d87c9acca56a9dfac56f152c98bd5dec748260ca5d7ba4bfe9fba95c1916921`.

The complete state manifest is BLAKE3 `9133cdc8def3d6b965ccc36f7bb9af65344c66c2197128baf7a088720b298095`, covering 303,315 records and 57,970,852,026 bytes. The recovery-input manifest is BLAKE3 `ca0847b0f45cd2b53a2ab84903b0df6628fc7ff16039a9946a0ec00f899e877d`, covering six records and 72,382,060 bytes.

The archive completed with status zero. Previously active node, HTTP, and policy services resumed; plaintext backup staging was removed. The independent desktop dataset retained 222,270,636,032 bytes available under its 256 GiB quota.

## Clean-root recovery

The deployed `radicle-backup-restore-verify` selected that exact archive, regenerated and matched both manifests, recovered the pinned node ID and fingerprint, counted 6,764 repositories, repeated the private-pilot semantic checks, printed `restore_result=verified`, exited zero, and removed its clean root.

A second isolated extraction checked the Bounded Exec migration through ordinary built-in Radicle tooling. Its first attempt failed closed because extraction preserved the `radicle` owner while the operator verifier ran as root. The root was removed by the trap and no acceptance output was produced. The corrected retry added `safe.directory` only for the isolated restored Bounded Exec repository. It then verified:

- canonical `main` `1baa4f552ae55923b025d99d08073286158836be`;
- solved issue ref `de02d0257d181fc61662fa8e028b2296c5b30f8f`;
- archived patch ref `97309eba9aed4ddb77934a4a49efd8c840e3be26` at the expected base/head;
- imported review metadata as attribution-only;
- Author `parent` sigrefs `d13faa9620a139c0eedc15eb4565e35934858c1c`.

No restored node was started. The temporary `/dev/shm` script, restore roots, and Borg runtime were removed. Production services remained active and the CI outbox was empty.

## Observation window

Initial probe `f84263b6fb01b9f4bf39d9c7de78ac5573840691fe3b232d8f22c64ad011100e` passed at `2026-07-27T01:20:15Z`. It bound exact local, Aspen, desktop, and public HTTPS refs; one local node; active services; empty CI outbox; cleanup; backup headroom; unchanged canonical `main`; and no guard execution.

Pueue task `158` is delayed by 24 hours. The probe itself rejects elapsed intervals below 86,400 seconds and writes its result atomically only after every invariant passes. The observation remains **in progress** until that task completes successfully and the result is reviewed.

## Non-claims

This evidence does not claim arbitrary Radicle correctness, source-host completeness, actor authenticity, approval equivalence, canonical eligibility or mutation, CI correctness, durability beyond the measured interval, secure deletion, or release readiness.
