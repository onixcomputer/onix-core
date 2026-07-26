# Design: Radicle-safe status marker

## Root cause

Radicle CLI's `strip_comments` state machine treats any line beginning with `<!--` as the start of an editor-only comment and only exits that state when a later line ends with `-->`. The former marker opened and closed on one line, so the sanitizer skipped that line and every later payload line. Pure status parsing never exercised this CLI normalization boundary.

## Change

Replace the HTML marker with the visible line `onix-radicle-ci-status:v1`. Keep it as the first line so live materialization can select exact bot-authored status comments. Preserve the one-line closed JSON payload and human bounded-observation text. Reject HTML-like, multiline, or whitespace-padded protocol markers through tests.

Model Radicle's relevant sanitizer behavior as a small pure test helper and prove the rendered status remains non-empty, unchanged, and parseable after normalization. This helper is regression evidence for the observed upstream behavior, not a claim of full Radicle CLI equivalence.

## Deployment

Redeploy the package through the existing strict-host-key Clan path. Requeue the previously retained exact patch result, verify the publisher succeeds and the stored signed comment begins with the visible marker, then remove temporary files. Do not invoke `guard --execute`.
