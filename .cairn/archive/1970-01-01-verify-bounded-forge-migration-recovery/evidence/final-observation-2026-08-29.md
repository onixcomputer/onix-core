# Final observation — 2026-08-29

## Window

The initial probe passed at `2026-07-27T01:20:15Z`. This final verification
ran at `2026-08-29T20:18:38Z`, an elapsed interval of roughly 33.8 days,
comfortably beyond the required 24-hour minimum.

## Unchanged canonical state

The migrated repository `z2CpqLFpdP36fZXYUK5ZNWxMibpCo` (bounded-exec) was
re-read from both Radicle storage roots on `britton-desktop`:

- owner storage `/home/brittonr/.radicle/storage`;
- replica storage `/var/lib/radicle/storage`.

Both roots agree and match the restored references recorded at migration
time:

- canonical `main` = `1baa4f552ae55923b025d99d08073286158836be`;
- solved issue ref = `de02d0257d181fc61662fa8e028b2296c5b30f8f`
  (`refs/cobs/xyz.radicle.issue/d9f9c0ad…`);
- archived patch ref = `97309eba9aed4ddb77934a4a49efd8c840e3be26`
  (`refs/cobs/xyz.radicle.patch/86c2607d…`).

No drift, tampering, or divergence was observed on either root across the
window.

## Verdict

The observation window is closed with unchanged canonical state. The
bounded forge migration recovery is accepted.

## Non-claims

This evidence does not claim arbitrary Radicle correctness, source-host
completeness, actor authenticity, approval equivalence, canonical
eligibility or mutation, CI correctness, durability beyond the measured
interval, secure deletion, or release readiness.
