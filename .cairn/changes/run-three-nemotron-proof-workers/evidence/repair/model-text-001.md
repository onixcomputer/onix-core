The baseline is green (11146 verified, 0 errors). Now let me investigate the leads with bounded reads.





The investigation is complete. All candidates are explicitly documented permanent trust boundaries/cryptographic axioms, and the baseline is green. Let me record findings.



Investigation complete. Final report:

## Result: NO-REPAIR (source-grounded)

**Baseline (unchanged snapshot, from `./verify`):** 11146 verified, 0 errors (warnings only: deprecated `is_None`, non-snake_case spec fns, Clone autodervies, `if`-in-patterns). This matches the parent-retained fresh production baseline; attribution belongs to the parent.

**Investigated leads (bounded reads only):**
- `src/nix_version.rs:709-840` — modeled path verified (`compare_versions_spec` equality on admitted inputs); `compare_versions_unmodeled_trusted` (762-764) is an explicitly documented `external_body` fallback promising only `result in {-1,0,1}`. Dispatch at 829-840 routes admitted inputs through verified helpers. Requirement `r[nix-version.compare-versions]` (requirements.md:1984-1985) is satisfied on the admitted domain; out-of-model scope is declared, not a defect.
- `src/markov.rs:19-40` — `confidence_meets` verified against the exact integer spec `count*100 >= total*threshold_pct` (cross-multiplication). Overflow-avoiding branch is Verus-verified. Stale comments about approximate/external-body approaches describe implementation structure, not a missing proof. Matches `r[markov.confidence]` (requirements.md:2736-2739).
- `src/chain.rs:840-863` — `hash_collision_free` is an explicit `external_body` idealized cryptographic axiom (Blake3 collision resistance). `r[chain.collision-free]` (requirements.md:638-642) labels it a trusted axiom. Not provable inside the finite model.
- `src/snapshot_integrity.rs:49-71` — `dual_hash_collision_resistant` and `dual_hash` are declared `external_body` axioms; tamper-detection requirements (requirements.md:3332-3346) are explicitly conditioned on collision resistance.

**Verification outcome:** No source edits were made, so no post-edit re-run was needed. `./verify` on the unchanged snapshot: 11146 verified, 0 errors.

**findings.md:** Written with (a) investigated targets/ranges, (b) source/verification facts separated from advisory reasoning, (c) exact verifier outcome, (d) no changed proof candidate (no source edits), and (e) remaining limits/trust assumptions.

**Conclusion:** All named candidates are either verified implementations matching their exact specs or explicitly documented permanent-trust/cryptographic-axiom boundaries (the 15 in `docs/proof-gap-sites.tsv`). No independently justified actionable proof defect or meaningful contract/trust gap exists in this snapshot. No proof body was removed; no preconditions/admits/external_bodies/unsafe/exemptions added; no contracts weakened or narrowed. A source-grounded NO-REPAIR result is the correct outcome.
