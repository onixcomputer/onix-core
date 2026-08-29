# Broker continuity predeployment

Date: 2026-08-28

## Finding

The deployed Onix closure pins hosted Kiln revision `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`. Its `kiln-adapter-radicle` command requires explicit `--profile` and `--runtime` arguments.

The existing Seaglass broker retained the historical environment-only command. The broker process was active, but a new admitted event would invoke an incompatible CLI shape.

## Repair

The staging configuration now pins legacy executor revision `8821e9adf15ad28838025bfbdd2e09c8d76fe5db` as `kiln-ci-legacy`. The existing broker command uses only that input. The Aspen canary continues to use hosted revision `69c0a6ac...`.

The focused gate executes the legacy adapter with malformed Defelo input. It requires the historical `radicle_json` diagnostic and rejects a closure that supplies the hosted CLI instead.

## Validation

- Existing `seaglass-kiln-ci-policy` baseline: PASS.
- Existing `kiln-aspen-canary-module` baseline: PASS.
- Full `britton-desktop` evaluation baseline: PASS.
- Repaired `seaglass-kiln-ci-policy`: PASS.
- Repaired `kiln-aspen-canary-module`: PASS.
- Repaired full `britton-desktop` evaluation: PASS.

This evidence proves configuration continuity only. A managed deployment and one real legacy broker event remain required.
