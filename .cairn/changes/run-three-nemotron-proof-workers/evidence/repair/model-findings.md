# Trellis Repair Investigation — Findings (guided follow-up)

## Session / attribution

- **This session (this repair pass):** I ran `./verify` on the **unchanged snapshot** in this worktree. Receipt: **11146 verified, 0 errors** (warnings only: deprecated `is_None`, non-snake_case spec fns, Clone autodervies, `if`-in-patterns). No source files were edited; `findings.md` is the only file written in this follow-up.
- **Parent baseline:** the fresh full-crate production baseline (11146 verified, zero errors, 15 explicit trust boundaries) is attributed to the parent, not to this repair pass. It is retained separately per `context.json` (`current_complete_baseline`).
- This is a guided follow-up to attempt 001. The source snapshot is unchanged; only `findings.md` is revised. The earlier overly strong global conclusion ("no meaningful contract/trust gap exists in the entire snapshot") is removed — a bounded investigation does not establish that.

## Denied tool attempt (retained honestly)

- An `ls -la` directory listing was attempted during this session and was **denied / not executed** (permission failure of the sandbox tooling, not a command result). It is noted here as a nonexecuted attempt; no filesystem listing from it is used as evidence.

## (1) Actual proof receipt

- `./verify` (this session, unchanged snapshot): **11146 verified, 0 errors**, 32 + 54 warnings (deprecated/non-snake_case/Clone/`if`-in-patterns). Warnings are non-fatal; no errors.
- This establishes that the Verus specifications discharge under the current model. It does **not** establish runtime cryptographic strength, semantic completeness, or coverage of inputs outside the modeled/admitted domains.

## (2) Model / axiom conditional guarantees (what the proof actually covers)

| Target | Source range | What is established | Conditional on |
|---|---|---|---|
| Nix version compare (admitted) | `src/nix_version.rs:829-840` | `compare_versions` routes admitted inputs to `compare_versions_modeled_exec` (711-719) and ensures `result as int == compare_versions_spec(a@, b@)` with `result in {-1,0,1}` when `admitted_version_model` and `a.len() <= usize::MAX - b.len()`. | Finite admitted domain only; out-of-model inputs go to the trusted fallback. |
| Nix version trusted fallback | `src/nix_version.rs:762-821` | `compare_versions_unmodeled_trusted` is `#[verifier::external_body]`; ensures only `result == -1 || result == 0 || result == 1`. | External body, not verified. |
| Markov confidence | `src/markov.rs:28-40` | Verified implementation matches exact integer spec `total > 0 && count*100 >= total*threshold_pct` under `total > 0, threshold_pct <= 100, count <= total`. | Admitted preconditions. |
| Chain collision-freedom | `src/chain.rs:840-863` | `hash_collision_free` is `#[verifier::external_body]` explicit idealized axiom (Blake3-modeled, per `r[chain.collision-free]` requirements.md:638-642). | Trusted axiom, not a runtime guarantee. |
| Snapshot integrity | `src/snapshot_integrity.rs:40-71, 149-243` | `dual_hash_collision_resistant` is `#[verifier::external_body]` axiom over `dual_hash_spec`; tamper-detection proofs (`data_tamper_detected` 164-186, `meta_tamper_detected` 191-211, `combined_commits_to_both` 233-243) discharge by invoking that axiom. | Trusted axiom over the *spec*, not over the executable `dual_hash`. |

Key distinction: the snapshot tamper-detection proofs are valid **within the model**, because they reason about the uninterpreted `dual_hash_spec` plus the explicit collision-resistance axiom. They do **not** prove the executable `dual_hash` (33-71) is collision-free. That is a model/axiom conditional guarantee, not a runtime theorem.

## (3) Source-derived advisory issues (trust gaps)

### Snapshot integrity: the collision-freedom axiom overstates the executable bridge

`src/snapshot_integrity.rs`:
- Comment (35-38): "In practice this is blake3(a || b). Modeled as uninterpreted with collision resistance kept as an explicit axiom below."
- Axiom (49-58): `dual_hash_collision_resistant` states that equal `dual_hash_spec` outputs imply equal inputs — an explicit idealization over the uninterpreted spec.
- Exec bridge (63-71): `dual_hash` is `#[verifier::external_body]` and performs **two wrapping arithmetic rounds** with multiplier `M = 6_364_136_223_846_793_005`, not the 256-bit Blake3 described in the comment:
  ```
  h = a;
  h = h.wrapping_mul(M).wrapping_add(b);
  h = h.wrapping_mul(M).wrapping_add(a ^ b);
  ```
  i.e. `dual_hash(a,b) = a*M^2 + b*M + (a ^ b) (mod 2^64)`.

Source-grounded arithmetic derivation (not an executed test, not verifier proof):
- `M` is odd (ends in 005), so `M` is a unit mod 2^64, but that is irrelevant to the `a=0` subfamily.
- For `a = 0`: `dual_hash(0,b) = b*M + (0 ^ b) = b*M + b = b*(M+1) (mod 2^64)`.
- `M+1 = 6_364_136_223_846_793_006 = 2 * 3_182_068_111_923_396_503`, where the second factor is odd. Hence `v2(M+1) = 1`.
- Therefore `b -> b*(M+1) (mod 2^64)` maps onto the even residues with a kernel of size 2: `b` and `b + 2^63` collide for every `b`.

Explicit runtime collision pair derived from the executable arithmetic:
- `dual_hash(0, 0) = 0`
- `dual_hash(0, 9223372036854775808) = 0`  (since `2^63 * (M+1) = 2^64 * odd ≡ 0 (mod 2^64)`)

Both inputs have `a = 0` and both produce combined hash `0`. This is a concrete collision in the executable `dual_hash` (source ranges 63-71), derived purely from the arithmetic — I did **not** execute a runtime test, and this derivation is **not** verifier proof.

Interpretation: The axiom is a deliberate explicit idealization over `dual_hash_spec`, and the proofs conditioned on it are internally consistent. But the executable bridge does **not** deliver the Blake3-like collision resistance the comment implies, and the exec's own ensures (`result == dual_hash_spec`, line 65) is itself `#[verifier::external_body]` / trusted, not proven. Thus there is a meaningful model-to-runtime trust gap for snapshot tamper detection at the runtime level: the spec-level proofs assume collision resistance that the two-round wrapping arithmetic does not provide (e.g. the `a=0` subfamily collides).

This is reported candidly as a source-grounded trust-gap finding. Preservation constraints prohibit weakening the existing `ensures`, adding exemptions/external_body, narrowing the axiom, or replacing the executable algorithm here; therefore **no admissible source repair exists for this gap** within the allowed repair role.

### Nix version: proof coverage is not full runtime correctness

`src/nix_version.rs:755-840`, `requirements.md:1984-1985`:
- The public `compare_versions` ensures the exact spec equality (`result as int == compare_versions_spec`) **only** under the admission precondition `admitted_version_model(a@) && admitted_version_model(b@) && a.len() <= usize::MAX - b.len()` (832-833).
- The fallback `compare_versions_unmodeled_trusted` (762-821) is `#[verifier::external_body]` and ensures only `result in {-1,0,1}` (764).
- Requirement `r[nix-version.compare-versions]` (requirements.md:1984-1985) states compare_versions "MUST compare two version strings component-by-component ... returning -1, 0, or 1" — an unqualified requirement.

So the finite-domain contract is green on the admitted model, but the full unqualified requirement is **not** established for all runtime inputs: out-of-model / length-overflow inputs carry only the normalized range guarantee from the trusted fallback. Out-of-model behavior is retained as an explicit, unverified limitation. No unbounded exploration is required or claimed; the gap is bounded to the fallback's external_body scope.

## (4) Admissible source repair found?

**No.** No independently justified, actionable source repair was found. No source files were edited. No proof body was removed, no new precondition/admit/external_body/unsafe/exemption was added, and no existing contract was weakened or narrowed. The two issues above are real, source-grounded trust gaps with no admissible repair under the preservation constraints (snapshot runtime collision; nix_version out-of-model fallback scope). A NO-REPAIR result can still contain meaningful trust gaps; explicit trust documentation and zero verifier errors do not make those gaps benign or prove runtime cryptography.

## Compact scoped report

- This session: `./verify` → 11146 verified, 0 errors on unchanged snapshot (warnings only). Parent baseline (11146/0/15) attributed separately.
- Verified code matches its specs on admitted/model domains (markov, nix_version modeled path, snapshot round-trip and tamper proofs conditioned on the axiom).
- Trust gaps retained: (a) `src/snapshot_integrity.rs:63-71` executable `dual_hash` is not collision-free — explicit derived collision `dual_hash(0,0) == dual_hash(0,9223372036854775808) == 0` from two wrapping rounds with odd multiplier `6_364_136_223_846_793_005`; the axiom/comment (Blake3) overstates the runtime bridge; no admissible repair. (b) `src/nix_version.rs:829-840` covers only admitted inputs; out-of-model fallback is external_body with range-only guarantee, so the unqualified `r[nix-version.compare-versions]` is not fully established.
- No source changes made; `findings.md` is the only artifact. `ls -la` attempt was denied/nonexecuted and is noted above.
