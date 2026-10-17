I have the source. Now let me check for the verifier and examine the multiplier parity to derive the collision. Let me check the workspace.




My own `./verify` call this session returned **11146 verified, 0 errors** on the unchanged snapshot. I now have both receipts and the source-grounded analysis. Let me write the revised `findings.md`.



The revised `findings.md` is complete. Summary of what was done:

**Session verification:** I ran `./verify` on the unchanged snapshot in this worktree — **11146 verified, 0 errors** (warnings only). This is attributed to this session; the parent baseline (11146/0/15) is attributed separately to the parent.

**Revised findings.md now distinguishes four categories:**
1. **Actual proof receipt** — my `./verify` call (11146/0), attributed to this session; parent baseline attributed to parent.
2. **Model/axiom conditional guarantees** — what Verus actually establishes (admitted nix_version path, markov confidence, chain/snapshot axioms and the tamper proofs conditioned on them).
3. **Source-derived advisory issues / trust gaps:**
   - **Snapshot integrity (`src/snapshot_integrity.rs:63-71`):** The executable `dual_hash` does two wrapping rounds with multiplier `6_364_136_223_846_793_005`, not Blake3. Source-grounded arithmetic derivation: `M` odd, `M+1 = 2·odd` so `v2(M+1)=1`; for `a=0`, `dual_hash(0,b) = b·(M+1) mod 2^64`, whose kernel is `{b, b+2^63}`. Explicit derived collision: `dual_hash(0, 0) == dual_hash(0, 9223372036854775808) == 0`. I did **not** execute a runtime test, and this derivation is **not** verifier proof — it's a candid model-to-runtime trust gap. The axiom/comment (Blake3) overstates the runtime bridge; no admissible repair is permitted (can't weaken `ensures`, replace algorithm, or add exemptions).
   - **Nix version (`src/nix_version.rs:829-840`, `requirements.md:1984-1985`):** public ensures covers only admitted inputs; the fallback is `external_body` with range-only guarantee, so the unqualified requirement is not fully established; out-of-model behavior retained as a limitation.
4. **Admissible source repair:** None found; source unchanged, only `findings.md` written.

**Honestly retained:** the denied `ls -la` attempt is noted as a nonexecuted permission failure. The unsupported global "no gap exists" conclusion was removed. No source files were edited; no contracts weakened.
