# Fix Radicle CI status publication

## Why

The deployed machine-readable publisher passed pure rendering tests but failed the real Radicle CLI boundary. A leading one-line HTML marker triggers Radicle's editor-comment sanitizer, which treats every following line as comment text and supplies an empty body. The publisher therefore exits nonzero and retains the job in the outbox.

## Outcome

Use a visible closed protocol marker that survives Radicle CLI comment normalization, retain the exact signed JSON payload and human non-claim, add positive and negative sanitizer regression tests, repair the stale command usage text, redeploy Aspen, and prove one exact existing patch status publishes without canonical-ref mutation.

## Non-goals

This change does not alter CI policy, rerun source checks, approve or merge a patch, grant canonical authority, execute the guard compare-and-swap, or claim that status publication proves CI correctness or merge eligibility.
