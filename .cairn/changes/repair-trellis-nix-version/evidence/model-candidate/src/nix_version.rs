//! Verified Nix version comparison.
//!
//! Implements the same algorithm as Nix's `compareVersions`: split at
//! `.` and `-` boundaries, classify components as numeric or alpha,
//! compare pairwise. Numeric beats alpha when types differ; empty
//! components compare as less than any non-empty component.

// Verus requires &Vec for @ view, not &[T]; u8→u64 cast in Verus blocks
#![allow(clippy::ptr_arg, clippy::cast_lossless)]

use vstd::prelude::*;

verus! {

/// Component classification: 0 = empty, 1 = numeric, 2 = alphabetic.
pub open spec fn classify_byte(b: u8) -> u8 {
    if b >= 48 && b <= 57 { 1 } // '0'-'9'
    else if (b >= 65 && b <= 90) || (b >= 97 && b <= 122) { 2 } // a-z, A-Z
    else { 0 } // separator or other
}

/// Spec: is this byte a version separator ('.' or '-')?
pub open spec fn is_separator(b: u8) -> bool {
    b == 46 || b == 45 // '.' or '-'
}

/// Spec: is this byte an ASCII digit?
pub open spec fn is_digit_byte(b: u8) -> bool {
    b >= 48 && b <= 57
}

/// Spec: is this byte an ASCII letter?
pub open spec fn is_alpha_byte(b: u8) -> bool {
    (b >= 65 && b <= 90) || (b >= 97 && b <= 122)
}

/// Well-formedness: all bytes are separator, digit, or alpha.
pub open spec fn well_formed_version(s: Seq<u8>) -> bool {
    forall|i: int| 0 <= i < s.len() ==> (
        is_separator(#[trigger] s[i]) || is_digit_byte(s[i]) || is_alpha_byte(s[i])
    )
}

// --- Spec helper functions ---

/// Advance past separator bytes from position i.
pub open spec fn skip_seps(s: Seq<u8>, i: int) -> int
    decreases (if s.len() >= i { s.len() - i } else { 0 })
{
    if i < 0 || i >= s.len() || !is_separator(s[i]) { i }
    else { skip_seps(s, i + 1) }
}

/// Advance to end of component (digit run or alpha run).
pub open spec fn comp_end(s: Seq<u8>, i: int, numeric: bool) -> int
    decreases (if s.len() >= i { s.len() - i } else { 0 })
{
    if i < 0 || i >= s.len() { i }
    else if numeric && is_digit_byte(s[i]) { comp_end(s, i + 1, numeric) }
    else if !numeric && is_alpha_byte(s[i]) { comp_end(s, i + 1, numeric) }
    else { i }
}

/// Parse integer from bytes s[i..end] (big-endian, no overflow).
pub open spec fn parse_num_from(s: Seq<u8>, i: int, end: int) -> int
    decreases end - i when 0 <= i && i <= end
{
    if i >= end { 0 }
    else { parse_num_from(s, i, end - 1) * 10 + (s[end - 1] - 48) as int }
}

/// Lexicographic comparison on subranges a[ai..a_end] vs b[bi..b_end].
pub open spec fn lex_cmp(
    a: Seq<u8>, ai: int, a_end: int,
    b: Seq<u8>, bi: int, b_end: int,
) -> int
    decreases (a_end - ai) + (b_end - bi) when ai <= a_end && bi <= b_end
{
    if ai >= a_end && bi >= b_end { 0 }
    else if ai >= a_end { -1 }
    else if bi >= b_end { 1 }
    else if a[ai] < b[bi] { -1 }
    else if a[ai] > b[bi] { 1 }
    else { lex_cmp(a, ai + 1, a_end, b, bi + 1, b_end) }
}

// --- Main version comparison spec ---

/// Fuel-bounded recursive version comparison.
/// Fuel starts at a.len() + b.len(), sufficient for well-formed inputs.
/// Returns 0 when fuel runs out (preserves algebraic properties).
pub open spec fn cv_fuel(
    a: Seq<u8>, ai: int, b: Seq<u8>, bi: int, fuel: nat,
) -> int
    decreases fuel
{
    if fuel == 0 { 0 }
    else {
        let ai2: int = skip_seps(a, ai);
        let bi2: int = skip_seps(b, bi);
        if ai2 >= a.len() && bi2 >= b.len() { 0 }
        else {
            let a_num: bool = if ai2 < a.len() { is_digit_byte(a[ai2]) } else { false };
            let b_num: bool = if bi2 < b.len() { is_digit_byte(b[bi2]) } else { false };
            let a_end: int = comp_end(a, ai2, a_num);
            let b_end: int = comp_end(b, bi2, b_num);
            if a_end == ai2 && b_end != bi2 { -1int }
            else if a_end != ai2 && b_end == bi2 { 1int }
            else if a_num && !b_num { 1int }
            else if !a_num && b_num { -1int }
            else if a_num {
                if parse_num_from(a, ai2, a_end) < parse_num_from(b, bi2, b_end) { -1int }
                else if parse_num_from(a, ai2, a_end) > parse_num_from(b, bi2, b_end) { 1int }
                else { cv_fuel(a, a_end, b, b_end, (fuel - 1) as nat) }
            } else {
                if lex_cmp(a, ai2, a_end, b, bi2, b_end) != 0 {
                    lex_cmp(a, ai2, a_end, b, bi2, b_end)
                }
                else { cv_fuel(a, a_end, b, b_end, (fuel - 1) as nat) }
            }
        }
    }
}

// r[depends nix-version.compare-versions]
/// Spec: compare two version strings. Returns -1, 0, or 1.
pub open spec fn compare_versions_spec(a: Seq<u8>, b: Seq<u8>) -> int {
    cv_fuel(a, 0, b, 0, (a.len() + b.len()) as nat)
}

// --- Proof helpers ---

/// lex_cmp antisymmetry: lex_cmp(a, b) == -lex_cmp(b, a).
proof fn lex_cmp_antisymmetric(
    a: Seq<u8>, ai: int, a_end: int,
    b: Seq<u8>, bi: int, b_end: int,
)
    requires 0 <= ai, ai <= a_end, a_end <= a.len(),
             0 <= bi, bi <= b_end, b_end <= b.len()
    ensures lex_cmp(a, ai, a_end, b, bi, b_end)
         == -lex_cmp(b, bi, b_end, a, ai, a_end)
    decreases (a_end - ai) + (b_end - bi)
{
    if ai < a_end && bi < b_end && a[ai] == b[bi] {
        lex_cmp_antisymmetric(a, ai + 1, a_end, b, bi + 1, b_end);
    }
}

/// lex_cmp reflexivity: lex_cmp(a, a) == 0.
proof fn lex_cmp_reflexive(a: Seq<u8>, ai: int, a_end: int)
    requires 0 <= ai, ai <= a_end, a_end <= a.len()
    ensures lex_cmp(a, ai, a_end, a, ai, a_end) == 0
    decreases a_end - ai
{
    if ai < a_end {
        lex_cmp_reflexive(a, ai + 1, a_end);
    }
}

/// lex_cmp range: result is in {-1, 0, 1}.
proof fn lex_cmp_range(
    a: Seq<u8>, ai: int, a_end: int,
    b: Seq<u8>, bi: int, b_end: int,
)
    requires 0 <= ai, ai <= a_end, a_end <= a.len(),
             0 <= bi, bi <= b_end, b_end <= b.len()
    ensures lex_cmp(a, ai, a_end, b, bi, b_end) == -1
         || lex_cmp(a, ai, a_end, b, bi, b_end) == 0
         || lex_cmp(a, ai, a_end, b, bi, b_end) == 1
    decreases (a_end - ai) + (b_end - bi)
{
    if ai < a_end && bi < b_end && a[ai] == b[bi] {
        lex_cmp_range(a, ai + 1, a_end, b, bi + 1, b_end);
    }
}

/// skip_seps returns a value >= i and <= s.len().
proof fn skip_seps_bounds(s: Seq<u8>, i: int)
    requires 0 <= i, i <= s.len()
    ensures i <= skip_seps(s, i), skip_seps(s, i) <= s.len()
    decreases s.len() - i
{
    if i < s.len() && is_separator(s[i]) {
        skip_seps_bounds(s, i + 1);
    }
}

/// comp_end returns a value >= i and <= s.len().
proof fn comp_end_bounds(s: Seq<u8>, i: int, numeric: bool)
    requires 0 <= i, i <= s.len()
    ensures i <= comp_end(s, i, numeric), comp_end(s, i, numeric) <= s.len()
    decreases s.len() - i
{
    if i < s.len() {
        if numeric && is_digit_byte(s[i]) {
            comp_end_bounds(s, i + 1, numeric);
        } else if !numeric && is_alpha_byte(s[i]) {
            comp_end_bounds(s, i + 1, numeric);
        }
    }
}

// --- Main proofs ---

/// cv_fuel antisymmetry: cv_fuel(a,b) == -cv_fuel(b,a).
proof fn cv_fuel_antisymmetric(
    a: Seq<u8>, ai: int, b: Seq<u8>, bi: int, fuel: nat,
)
    requires 0 <= ai, ai <= a.len(), 0 <= bi, bi <= b.len()
    ensures cv_fuel(a, ai, b, bi, fuel) == -cv_fuel(b, bi, a, ai, fuel)
    decreases fuel
{
    if fuel > 0 {
        skip_seps_bounds(a, ai);
        skip_seps_bounds(b, bi);
        let ai2 = skip_seps(a, ai);
        let bi2 = skip_seps(b, bi);
        // Both exhausted: both return 0
        if ai2 >= a.len() && bi2 >= b.len() {
            assert(cv_fuel(a, ai, b, bi, fuel) == 0);
            assert(cv_fuel(b, bi, a, ai, fuel) == 0);
        } else if ai2 < a.len() && bi2 < b.len() {
            // Both have bytes
            let a_dig = is_digit_byte(a[ai2]);
            let b_dig = is_digit_byte(b[bi2]);
            comp_end_bounds(a, ai2, a_dig);
            comp_end_bounds(b, bi2, b_dig);
            let a_end = comp_end(a, ai2, a_dig);
            let b_end = comp_end(b, bi2, b_dig);
            if a_end == ai2 && b_end != bi2 {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
                assert(cv_fuel(b, bi, a, ai, fuel) == 1);
            } else if a_end != ai2 && b_end == bi2 {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
                assert(cv_fuel(b, bi, a, ai, fuel) == -1);
            } else if a_dig && !b_dig {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
                assert(cv_fuel(b, bi, a, ai, fuel) == -1);
            } else if !a_dig && b_dig {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
                assert(cv_fuel(b, bi, a, ai, fuel) == 1);
            } else if a_dig {
                if parse_num_from(a, ai2, a_end) == parse_num_from(b, bi2, b_end) {
                    cv_fuel_antisymmetric(a, a_end, b, b_end, (fuel - 1) as nat);
                }
            } else {
                lex_cmp_antisymmetric(a, ai2, a_end, b, bi2, b_end);
                if lex_cmp(a, ai2, a_end, b, bi2, b_end) == 0 {
                    cv_fuel_antisymmetric(a, a_end, b, b_end, (fuel - 1) as nat);
                }
            }
        } else if ai2 < a.len() {
            let a_dig = is_digit_byte(a[ai2]);
            comp_end_bounds(a, ai2, a_dig);
            let a_end = comp_end(a, ai2, a_dig);
            assert(comp_end(b, bi2, false) == bi2);
            if a_end == ai2 && !a_dig {
                lex_cmp_antisymmetric(a, ai2, a_end, b, bi2, bi2);
                cv_fuel_antisymmetric(a, a_end, b, bi2, (fuel - 1) as nat);
            } else {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
                assert(cv_fuel(b, bi, a, ai, fuel) == -1);
            }
        } else {
            let b_dig = is_digit_byte(b[bi2]);
            comp_end_bounds(b, bi2, b_dig);
            let b_end = comp_end(b, bi2, b_dig);
            assert(comp_end(a, ai2, false) == ai2);
            if b_end == bi2 && !b_dig {
                lex_cmp_antisymmetric(a, ai2, ai2, b, bi2, b_end);
                cv_fuel_antisymmetric(a, ai2, b, b_end, (fuel - 1) as nat);
            } else {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
                assert(cv_fuel(b, bi, a, ai, fuel) == 1);
            }
        }
    } else {
        assert(cv_fuel(a, ai, b, bi, fuel) == 0);
        assert(cv_fuel(b, bi, a, ai, fuel) == 0);
    }
}

// r[verify nix-version.compare-versions]
/// Antisymmetric: compare(a, b) == -compare(b, a).
pub proof fn compare_versions_antisymmetric(a: Seq<u8>, b: Seq<u8>)
    ensures compare_versions_spec(a, b) == -compare_versions_spec(b, a)
{
    // a.len() + b.len() == b.len() + a.len(), so same fuel
    cv_fuel_antisymmetric(a, 0, b, 0, (a.len() + b.len()) as nat);
}

/// cv_fuel reflexivity: cv_fuel(a, a) == 0.
proof fn cv_fuel_reflexive(a: Seq<u8>, ai: int, fuel: nat)
    requires 0 <= ai, ai <= a.len()
    ensures cv_fuel(a, ai, a, ai, fuel) == 0
    decreases fuel
{
    if fuel > 0 {
        skip_seps_bounds(a, ai);
        let ai2 = skip_seps(a, ai);
        if ai2 < a.len() {
            let a_dig = is_digit_byte(a[ai2]);
            comp_end_bounds(a, ai2, a_dig);
            let a_end = comp_end(a, ai2, a_dig);
            if a_end > ai2 {
                if !a_dig {
                    lex_cmp_reflexive(a, ai2, a_end);
                }
                cv_fuel_reflexive(a, a_end, (fuel - 1) as nat);
            } else {
                lex_cmp_reflexive(a, ai2, a_end);
                cv_fuel_reflexive(a, ai2, (fuel - 1) as nat);
            }
        }
    }
}

// r[verify nix-version.compare-versions]
/// Reflexive: compare(a, a) == 0.
pub proof fn compare_versions_reflexive(a: Seq<u8>)
    ensures compare_versions_spec(a, a) == 0
{
    cv_fuel_reflexive(a, 0, (a.len() + a.len()) as nat);
}

/// cv_fuel range: result is in {-1, 0, 1}.
proof fn cv_fuel_range(
    a: Seq<u8>, ai: int, b: Seq<u8>, bi: int, fuel: nat,
)
    requires 0 <= ai, ai <= a.len(), 0 <= bi, bi <= b.len()
    ensures cv_fuel(a, ai, b, bi, fuel) == -1
         || cv_fuel(a, ai, b, bi, fuel) == 0
         || cv_fuel(a, ai, b, bi, fuel) == 1
    decreases fuel
{
    if fuel > 0 {
        skip_seps_bounds(a, ai);
        skip_seps_bounds(b, bi);
        let ai2 = skip_seps(a, ai);
        let bi2 = skip_seps(b, bi);
        if ai2 < a.len() && bi2 < b.len() {
            let a_dig = is_digit_byte(a[ai2]);
            let b_dig = is_digit_byte(b[bi2]);
            comp_end_bounds(a, ai2, a_dig);
            comp_end_bounds(b, bi2, b_dig);
            let a_end = comp_end(a, ai2, a_dig);
            let b_end = comp_end(b, bi2, b_dig);
            if a_end == ai2 && b_end != bi2 {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
            } else if a_end != ai2 && b_end == bi2 {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
            } else if a_dig && !b_dig {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
            } else if !a_dig && b_dig {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
            } else if a_dig {
                if parse_num_from(a, ai2, a_end) == parse_num_from(b, bi2, b_end) {
                    cv_fuel_range(a, a_end, b, b_end, (fuel - 1) as nat);
                }
            } else {
                lex_cmp_range(a, ai2, a_end, b, bi2, b_end);
                if lex_cmp(a, ai2, a_end, b, bi2, b_end) == 0 {
                    cv_fuel_range(a, a_end, b, b_end, (fuel - 1) as nat);
                }
            }
        } else if ai2 < a.len() {
            let a_dig = is_digit_byte(a[ai2]);
            comp_end_bounds(a, ai2, a_dig);
            let a_end = comp_end(a, ai2, a_dig);
            assert(comp_end(b, bi2, false) == bi2);
            if a_end == ai2 && !a_dig {
                lex_cmp_range(a, ai2, a_end, b, bi2, bi2);
                cv_fuel_range(a, a_end, b, bi2, (fuel - 1) as nat);
            } else {
                assert(cv_fuel(a, ai, b, bi, fuel) == 1);
            }
        } else if bi2 < b.len() {
            let b_dig = is_digit_byte(b[bi2]);
            comp_end_bounds(b, bi2, b_dig);
            let b_end = comp_end(b, bi2, b_dig);
            assert(comp_end(a, ai2, false) == ai2);
            if b_end == bi2 && !b_dig {
                lex_cmp_range(a, ai2, ai2, b, bi2, b_end);
                cv_fuel_range(a, ai2, b, b_end, (fuel - 1) as nat);
            } else {
                assert(cv_fuel(a, ai, b, bi, fuel) == -1);
            }
        } else {
            assert(cv_fuel(a, ai, b, bi, fuel) == 0);
        }
    } else {
        assert(cv_fuel(a, ai, b, bi, fuel) == 0);
    }
}

// r[verify nix-version.compare-versions]
/// Result is always in {-1, 0, 1}.
pub proof fn compare_versions_range(a: Seq<u8>, b: Seq<u8>)
    ensures compare_versions_spec(a, b) == -1
         || compare_versions_spec(a, b) == 0
         || compare_versions_spec(a, b) == 1
{
    cv_fuel_range(a, 0, b, 0, (a.len() + b.len()) as nat);
}

// --- admitted finite bridge model ---

/// Longest numeric component admitted by the finite bridge model.
/// Components above this length stay delegated to the trusted bridge.
pub const MAX_MODELED_NUMERIC_COMPONENT_LEN: usize = 1;

/// Spec: finite model admission for version bytes from index `i` with a current digit-run length.
pub open spec fn admitted_version_model_from(s: Seq<u8>, i: int, current_digit_run: int) -> bool
    decreases s.len() - i when 0 <= i && i <= s.len()
{
    if i >= s.len() {
        true
    } else if is_separator(s[i]) {
        admitted_version_model_from(s, i + 1, 0)
    } else if is_digit_byte(s[i]) {
        current_digit_run < MAX_MODELED_NUMERIC_COMPONENT_LEN as int
            && admitted_version_model_from(s, i + 1, current_digit_run + 1)
    } else if is_alpha_byte(s[i]) {
        admitted_version_model_from(s, i + 1, 0)
    } else {
        false
    }
}

/// Spec: admitted finite model for a version byte sequence.
pub open spec fn admitted_version_model(s: Seq<u8>) -> bool {
    admitted_version_model_from(s, 0, 0)
}

proof fn admitted_skip_seps_suffix(s: Seq<u8>, i: int)
    requires
        admitted_version_model_from(s, i, 0),
        0 <= i <= s.len(),
    ensures admitted_version_model_from(s, skip_seps(s, i), 0)
    decreases s.len() - i
{
    if i < s.len() && is_separator(s[i]) {
        admitted_skip_seps_suffix(s, i + 1);
    } else {
        assert(skip_seps(s, i) == i);
    }
}

proof fn admitted_digit_component_single(s: Seq<u8>, i: int)
    requires
        admitted_version_model_from(s, i, 0),
        0 <= i < s.len(),
        is_digit_byte(s[i]),
    ensures
        comp_end(s, i, true) <= i + 1,
        admitted_version_model_from(s, comp_end(s, i, true), 0),
    decreases s.len() - i
{
    assert(admitted_version_model_from(s, i + 1, 1));
    if i + 1 < s.len() {
        if is_digit_byte(s[i + 1]) {
            assert(!admitted_version_model_from(s, i + 1, 1));
            assert(false);
        } else {
            assert(comp_end(s, i + 1, true) == i + 1);
            assert(comp_end(s, i, true) == i + 1);
            assert(admitted_version_model_from(s, i + 1, 0));
        }
    } else {
        assert(comp_end(s, i + 1, true) == i + 1);
        assert(comp_end(s, i, true) == i + 1);
        assert(admitted_version_model_from(s, i + 1, 0));
    }
}

proof fn admitted_alpha_component_suffix(s: Seq<u8>, i: int)
    requires
        admitted_version_model_from(s, i, 0),
        0 <= i <= s.len(),
    ensures admitted_version_model_from(s, comp_end(s, i, false), 0)
    decreases s.len() - i
{
    if i < s.len() && is_alpha_byte(s[i]) {
        admitted_alpha_component_suffix(s, i + 1);
    } else {
        assert(comp_end(s, i, false) == i);
    }
}

// r[impl verification-gaps.nix-version-bridge-decomposition]
/// Decide whether a version byte sequence is inside the finite modeled subset.
pub fn admitted_version_model_from_exec(
    s: &Vec<u8>,
    i: usize,
    current_digit_run: usize,
) -> (result: bool)
    requires
        i <= s.len(),
        current_digit_run <= MAX_MODELED_NUMERIC_COMPONENT_LEN,
    ensures result == admitted_version_model_from(s@, i as int, current_digit_run as int)
    decreases s.len() - i
{
    if i >= s.len() {
        true
    } else {
        let byte = s[i];
        if byte == 46 || byte == 45 {
            admitted_version_model_from_exec(s, i + 1, 0)
        } else if byte >= 48 && byte <= 57 {
            if current_digit_run < MAX_MODELED_NUMERIC_COMPONENT_LEN {
                admitted_version_model_from_exec(s, i + 1, current_digit_run + 1)
            } else {
                false
            }
        } else if (byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122) {
            admitted_version_model_from_exec(s, i + 1, 0)
        } else {
            false
        }
    }
}

// r[impl verification-gaps.nix-version-bridge-decomposition]
/// Decide whether a version byte sequence is inside the finite modeled subset.
pub fn admitted_version_model_exec(s: &Vec<u8>) -> (result: bool)
    ensures result == admitted_version_model(s@)
{
    admitted_version_model_from_exec(s, 0, 0)
}

// r[impl verification-gaps.nix-version-bridge-decomposition]
/// Decide whether a comparison can be claimed by the finite model wrapper.
pub fn admits_compare_versions(a: &Vec<u8>, b: &Vec<u8>) -> (result: bool)
    ensures result == (admitted_version_model(a@) && admitted_version_model(b@))
{
    let a_ok = admitted_version_model_exec(a);
    let b_ok = admitted_version_model_exec(b);
    a_ok && b_ok
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Skip version separators in the executable modeled comparator.
pub fn skip_seps_exec(s: &Vec<u8>, i: usize) -> (result: usize)
    requires i <= s.len()
    ensures result as int == skip_seps(s@, i as int), result <= s.len()
    decreases s.len() - i
{
    proof { skip_seps_bounds(s@, i as int); }
    if i < s.len() && (s[i] == 46 || s[i] == 45) {
        skip_seps_exec(s, i + 1)
    } else {
        i
    }
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Find the end of the current numeric or alphabetic component.
pub fn comp_end_exec(s: &Vec<u8>, i: usize, numeric: bool) -> (result: usize)
    requires i <= s.len()
    ensures result as int == comp_end(s@, i as int, numeric), i <= result, result <= s.len()
    decreases s.len() - i
{
    proof { comp_end_bounds(s@, i as int, numeric); }
    if i < s.len() {
        let byte = s[i];
        if numeric && byte >= 48 && byte <= 57 {
            comp_end_exec(s, i + 1, numeric)
        } else if !numeric && ((byte >= 65 && byte <= 90) || (byte >= 97 && byte <= 122)) {
            comp_end_exec(s, i + 1, numeric)
        } else {
            i
        }
    } else {
        i
    }
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Parse an admitted numeric component into the mathematical numeric value.
pub fn parse_num_from_exec(s: &Vec<u8>, i: usize, end: usize) -> (result: u64)
    requires
        i <= end,
        end <= s.len(),
        end - i <= MAX_MODELED_NUMERIC_COMPONENT_LEN,
        forall|j: int| i as int <= j < end as int ==> is_digit_byte(#[trigger] s@[j]),
    ensures result as int == parse_num_from(s@, i as int, end as int)
    decreases end - i
{
    if i >= end {
        0
    } else {
        let prefix = parse_num_from_exec(s, i, end - 1);
        let digit = (s[end - 1] - 48) as u64;
        proof {
            assert(is_digit_byte(s@[(end - 1) as int]));
            assert(digit <= 9);
            assert(end - i <= 1);
            assert(i == end - 1);
            assert(prefix == 0);
            assert(parse_num_from(s@, i as int, end as int) == digit as int);
        }
        digit
    }
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Executable lexicographic comparison for modeled alphabetic components.
pub fn lex_cmp_exec(
    a: &Vec<u8>, ai: usize, a_end: usize,
    b: &Vec<u8>, bi: usize, b_end: usize,
) -> (result: i8)
    requires ai <= a_end, a_end <= a.len(), bi <= b_end, b_end <= b.len()
    ensures result as int == lex_cmp(a@, ai as int, a_end as int, b@, bi as int, b_end as int),
            result == -1 || result == 0 || result == 1
    decreases (a_end - ai) + (b_end - bi)
{
    proof { lex_cmp_range(a@, ai as int, a_end as int, b@, bi as int, b_end as int); }
    if ai >= a_end && bi >= b_end {
        0
    } else if ai >= a_end {
        -1
    } else if bi >= b_end {
        1
    } else if a[ai] < b[bi] {
        -1
    } else if a[ai] > b[bi] {
        1
    } else {
        lex_cmp_exec(a, ai + 1, a_end, b, bi + 1, b_end)
    }
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Verified executable comparator for admitted finite-model inputs.
pub fn compare_versions_modeled_fuel_exec(
    a: &Vec<u8>, ai: usize, b: &Vec<u8>, bi: usize, fuel: usize,
) -> (result: i8)
    requires
        ai <= a.len(),
        bi <= b.len(),
        fuel <= a.len() + b.len(),
        admitted_version_model_from(a@, ai as int, 0),
        admitted_version_model_from(b@, bi as int, 0),
    ensures result as int == cv_fuel(a@, ai as int, b@, bi as int, fuel as nat),
            result == -1 || result == 0 || result == 1
    decreases fuel
{
    proof { cv_fuel_range(a@, ai as int, b@, bi as int, fuel as nat); }
    if fuel == 0 {
        0
    } else {
        let ai2 = skip_seps_exec(a, ai);
        let bi2 = skip_seps_exec(b, bi);
        proof {
            admitted_skip_seps_suffix(a@, ai as int);
            admitted_skip_seps_suffix(b@, bi as int);
        }
        if ai2 >= a.len() && bi2 >= b.len() {
            0
        } else {
            let a_num = if ai2 < a.len() { a[ai2] >= 48 && a[ai2] <= 57 } else { false };
            let b_num = if bi2 < b.len() { b[bi2] >= 48 && b[bi2] <= 57 } else { false };
            let a_end = comp_end_exec(a, ai2, a_num);
            let b_end = comp_end_exec(b, bi2, b_num);
            proof {
                if ai2 < a.len() && a_num {
                    admitted_digit_component_single(a@, ai2 as int);
                    assert(a_end - ai2 <= MAX_MODELED_NUMERIC_COMPONENT_LEN);
                } else {
                    admitted_alpha_component_suffix(a@, ai2 as int);
                }
                if bi2 < b.len() && b_num {
                    admitted_digit_component_single(b@, bi2 as int);
                    assert(b_end - bi2 <= MAX_MODELED_NUMERIC_COMPONENT_LEN);
                } else {
                    admitted_alpha_component_suffix(b@, bi2 as int);
                }
            }
            if a_end == ai2 && b_end != bi2 {
                -1
            } else if a_end != ai2 && b_end == bi2 {
                1
            } else if a_num && !b_num {
                1
            } else if !a_num && b_num {
                -1
            } else if a_num {
                let a_val = parse_num_from_exec(a, ai2, a_end);
                let b_val = parse_num_from_exec(b, bi2, b_end);
                if a_val < b_val {
                    -1
                } else if a_val > b_val {
                    1
                } else {
                    compare_versions_modeled_fuel_exec(a, a_end, b, b_end, fuel - 1)
                }
            } else {
                let lex = lex_cmp_exec(a, ai2, a_end, b, bi2, b_end);
                if lex != 0 {
                    lex
                } else {
                    compare_versions_modeled_fuel_exec(a, a_end, b, b_end, fuel - 1)
                }
            }
        }
    }
}

// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Compare admitted finite-model inputs without delegating through trusted `compare_versions`.
pub fn compare_versions_modeled_exec(a: &Vec<u8>, b: &Vec<u8>) -> (result: i8)
    requires
        admitted_version_model(a@),
        admitted_version_model(b@),
        a.len() <= usize::MAX - b.len(),
    ensures result as int == compare_versions_spec(a@, b@), result == -1 || result == 0 || result == 1
{
    compare_versions_modeled_fuel_exec(a, 0, b, 0, a.len() + b.len())
}

// r[impl verification-gaps.nix-version-bridge-decomposition]
// r[impl verification-gaps.nix-version-modeled-compare-bridge]
/// Compare only admitted finite-model inputs; reject out-of-model bytes explicitly.
pub fn compare_versions_modeled(a: &Vec<u8>, b: &Vec<u8>) -> (result: Option<i8>)
    requires a.len() <= usize::MAX - b.len()
    ensures
        match result {
            Some(r) => admitted_version_model(a@) && admitted_version_model(b@)
                && r as int == compare_versions_spec(a@, b@)
                && (r == -1 || r == 0 || r == 1),
            None => !(admitted_version_model(a@) && admitted_version_model(b@)),
        }
{
    if admits_compare_versions(a, b) {
        Some(compare_versions_modeled_exec(a, b))
    } else {
        None
    }
}

// r[verify verification-gaps.nix-version-bridge-decomposition]
/// The finite wrapper rejects out-of-model inputs instead of claiming verified ordering.
pub proof fn admitted_compare_requires_left(a: Seq<u8>, b: Seq<u8>)
    ensures !admitted_version_model(a) ==> !(admitted_version_model(a) && admitted_version_model(b))
{}

// r[verify verification-gaps.nix-version-modeled-compare-bridge]
/// The modeled comparator reuses the existing comparison spec for admitted inputs.
pub proof fn modeled_compare_spec_is_existing_spec(a: Seq<u8>, b: Seq<u8>)
    ensures compare_versions_spec(a, b) == cv_fuel(a, 0, b, 0, (a.len() + b.len()) as nat)
{}

// --- compare_versions exec ---

/// Trusted fallback for version strings outside the finite modeled subset.
///
/// The broad exec/spec equality claim was narrowed out of this trusted bridge:
/// admitted finite-model inputs now flow through verified executable helpers in
/// `compare_versions`, while this fallback only promises a normalized ordering
/// for out-of-model or length-overflow cases.
/// @verified-logic:permanent-z3-limit — full unbounded exec/spec connection remains trusted only for fallback behavior
#[verifier::external_body]
fn compare_versions_unmodeled_trusted(a: &Vec<u8>, b: &Vec<u8>) -> (result: i8)
    ensures result == -1 || result == 0 || result == 1
{
    let mut ai: usize = 0;
    let mut bi: usize = 0;

    loop {
        // Skip separators
        while ai < a.len() && (a[ai] == b'.' || a[ai] == b'-') { ai += 1; }
        while bi < b.len() && (b[bi] == b'.' || b[bi] == b'-') { bi += 1; }

        // Both exhausted → equal
        if ai >= a.len() && bi >= b.len() { return 0; }

        // Extract components
        let a_start = ai;
        let b_start = bi;
        let a_numeric = ai < a.len() && a[ai].is_ascii_digit();
        let b_numeric = bi < b.len() && b[bi].is_ascii_digit();

        if a_numeric {
            while ai < a.len() && a[ai].is_ascii_digit() { ai += 1; }
        } else {
            while ai < a.len() && a[ai].is_ascii_alphabetic() { ai += 1; }
        }
        if b_numeric {
            while bi < b.len() && b[bi].is_ascii_digit() { bi += 1; }
        } else {
            while bi < b.len() && b[bi].is_ascii_alphabetic() { bi += 1; }
        }

        let a_comp = &a[a_start..ai];
        let b_comp = &b[b_start..bi];

        // Empty component loses
        if a_comp.is_empty() && !b_comp.is_empty() { return -1; }
        if !a_comp.is_empty() && b_comp.is_empty() { return 1; }

        // Type mismatch: numeric > alpha
        if a_numeric && !b_numeric { return 1; }
        if !a_numeric && b_numeric { return -1; }

        // Same type: compare
        if a_numeric {
            // Strip leading zeros and compare numerically
            let a_val = parse_numeric(a_comp);
            let b_val = parse_numeric(b_comp);
            if a_val < b_val { return -1; }
            if a_val > b_val { return 1; }
        } else {
            // Lexicographic
            match a_comp.cmp(b_comp) {
                std::cmp::Ordering::Less => return -1,
                std::cmp::Ordering::Greater => return 1,
                std::cmp::Ordering::Equal => {}
            }
        }
    }
}

// r[impl nix-version.compare-versions]
/// Compare two Nix version strings.
///
/// Inputs admitted by the finite model are compared by verified executable
/// helpers. Out-of-model inputs stay on the explicit trusted fallback and carry
/// only a range guarantee.
pub fn compare_versions(a: &Vec<u8>, b: &Vec<u8>) -> (result: i8)
    ensures
        result == -1 || result == 0 || result == 1,
        admitted_version_model(a@) && admitted_version_model(b@) && a.len() <= usize::MAX - b.len()
            ==> result as int == compare_versions_spec(a@, b@),
{
    if admits_compare_versions(a, b) && a.len() <= usize::MAX - b.len() {
        compare_versions_modeled_exec(a, b)
    } else {
        compare_versions_unmodeled_trusted(a, b)
    }
}

// --- parse_drv_name ---

// r[depends nix-version.parse-drv-name]
/// Spec: split "name-version" at the first digit after a hyphen.
/// Returns (name_end_index). Version starts at name_end + 1.
pub open spec fn parse_drv_name_spec(s: Seq<u8>) -> int {
    parse_drv_name_helper(s, 0)
}

/// Helper: linear scan from index `i` for '-' followed by a digit.
pub open spec fn parse_drv_name_helper(s: Seq<u8>, i: int) -> int
    decreases s.len() - i
{
    if i >= s.len() - 1 {
        s.len() as int
    } else if s[i] == 45 && s[i + 1] >= 48 && s[i + 1] <= 57 {
        i
    } else {
        parse_drv_name_helper(s, i + 1)
    }
}

/// Helper: the recursive spec skips non-matching positions.
proof fn parse_drv_name_skip(s: Seq<u8>, i: int)
    requires
        0 <= i < s.len() - 1,
        !(s[i] == 45 && s[i + 1] >= 48 && s[i + 1] <= 57),
    ensures parse_drv_name_helper(s, i) == parse_drv_name_helper(s, i + 1)
{}

/// Helper: bounds on parse_drv_name_helper result.
proof fn parse_drv_name_helper_bounds(s: Seq<u8>, i: int)
    requires 0 <= i <= s.len()
    ensures parse_drv_name_helper(s, i) <= s.len() as int
    decreases s.len() - i
{
    if i >= s.len() - 1 {
        // Base: returns s.len()
    } else if s[i] == 45 && s[i + 1] >= 48 && s[i + 1] <= 57 {
        // Match: returns i, and i < s.len()
    } else {
        parse_drv_name_helper_bounds(s, i + 1);
    }
}

// r[impl nix-version.parse-drv-name]
/// Split a derivation name into name and version parts.
/// Returns the index where the name ends (version starts at index + 1).
/// Returns `s.len()` if no version part is found.
pub fn parse_drv_name(s: &Vec<u8>) -> (result: usize)
    ensures result as int == parse_drv_name_spec(s@),
            result <= s.len()
{
    let mut i: usize = 0;
    proof { parse_drv_name_helper_bounds(s@, 0); }
    while i < s.len()
        invariant
            i <= s.len(),
            parse_drv_name_spec(s@) == parse_drv_name_helper(s@, i as int),
        decreases s.len() - i,
    {
        if s[i] == 45 && i + 1 < s.len() && s[i + 1] >= 48 && s[i + 1] <= 57 {
            assert(parse_drv_name_helper(s@, i as int) == i as int);
            return i;
        }
        // Not a match — show the helper skips this position
        if i < s.len() - 1 {
            proof { parse_drv_name_skip(s@, i as int); }
        }
        // else i >= s.len() - 1: next iteration won't enter the loop
        i = i + 1;
    }
    // i == s.len(): helper(s, s.len()) base case
    s.len()
}

} // verus!

/// Parse a numeric component, capping at `u64::MAX` for overflow safety.
fn parse_numeric(bytes: &[u8]) -> u64 {
    let mut val: u64 = 0;
    for &b in bytes {
        let digit = (b - b'0') as u64;
        val = match val.checked_mul(10).and_then(|v| v.checked_add(digit)) {
            Some(v) => v,
            None => return u64::MAX,
        };
    }
    val
}

#[cfg(test)]
mod tests {
    use proptest::prelude::*;

    use super::*;

    fn v(s: &str) -> Vec<u8> {
        s.as_bytes().to_vec()
    }

    // r[verify nix-version.compare-versions]
    #[test]
    fn test_compare_versions() {
        // Basic numeric comparison
        assert_eq!(compare_versions(&v("1.0"), &v("2.0")), -1);
        assert_eq!(compare_versions(&v("2.0"), &v("1.0")), 1);
        assert_eq!(compare_versions(&v("1.0"), &v("1.0")), 0);

        // Multi-component
        assert_eq!(compare_versions(&v("1.2.3"), &v("1.2.4")), -1);
        assert_eq!(compare_versions(&v("1.3.0"), &v("1.2.9")), 1);

        // Numeric vs alpha: numeric wins
        assert_eq!(compare_versions(&v("1.0"), &v("1.a")), 1);

        // Leading zeros don't matter
        assert_eq!(compare_versions(&v("1.01"), &v("1.1")), 0);

        // Hyphen as separator
        assert_eq!(compare_versions(&v("1.0-pre1"), &v("1.0-pre2")), -1);

        // Empty vs non-empty
        assert_eq!(compare_versions(&v("1.0"), &v("1.0.1")), -1);
    }

    // r[verify nix-version.compare-versions]
    // r[verify verification-gaps.nix-version-modeled-compare-bridge]
    #[test]
    fn test_compare_versions_narrowed_trust_boundary() {
        let admitted_left = v("2.3.2");
        let admitted_right = v("2.3.9");
        assert!(admitted_version_model_exec(&admitted_left));
        assert!(admitted_version_model_exec(&admitted_right));
        assert_eq!(compare_versions_modeled(&admitted_left, &admitted_right), Some(-1));
        assert_eq!(compare_versions(&admitted_left, &admitted_right), -1);

        let unmodeled_left = v("2.3.10");
        let unmodeled_right = v("2.3.2");
        assert!(!admitted_version_model_exec(&unmodeled_left));
        assert_eq!(compare_versions_modeled(&unmodeled_left, &unmodeled_right), None);
        assert_eq!(compare_versions(&unmodeled_left, &unmodeled_right), 1);
    }

    // r[verify nix-version.parse-drv-name]
    #[test]
    fn test_parse_drv_name() {
        assert_eq!(parse_drv_name(&v("hello-2.10")), 5);
        assert_eq!(parse_drv_name(&v("nix-2.3.1")), 3);
        assert_eq!(parse_drv_name(&v("no-version-here")), 15);
        assert_eq!(parse_drv_name(&v("gcc-13.2.0")), 3);
    }

    // r[verify verification-gaps.nix-version-bridge-decomposition]
    // r[verify verification-gaps.nix-version-modeled-compare-bridge]
    #[test]
    fn test_modeled_admission_and_rejection() {
        assert!(admitted_version_model_exec(&v("2.3.9-pre1")));
        assert_eq!(compare_versions_modeled(&v("2.3.2"), &v("2.3.9")), Some(-1));
        assert_eq!(compare_versions_modeled(&v("1.0"), &v("1.0")), Some(0));
        assert_eq!(compare_versions_modeled(&v("2.a"), &v("2.1")), Some(-1));

        assert!(!admitted_version_model_exec(&v("1_0")));
        assert_eq!(compare_versions_modeled(&v("1_0"), &v("1.0")), None);

        let too_long_numeric = v("10");
        assert!(!admitted_version_model_exec(&too_long_numeric));
        assert_eq!(compare_versions_modeled(&too_long_numeric, &too_long_numeric), None);
    }

    proptest! {
        // r[verify nix-version.compare-versions]
        #[test]
        fn prop_compare_reflexive(
            s in "[0-9a-z.\\-]{1,20}",
        ) {
            let v = s.into_bytes();
            prop_assert_eq!(compare_versions(&v, &v), 0);
        }

        // r[verify nix-version.compare-versions]
        #[test]
        fn prop_compare_antisymmetric(
            a in "[0-9a-z.]{1,10}",
            b in "[0-9a-z.]{1,10}",
        ) {
            let va = a.into_bytes();
            let vb = b.into_bytes();
            let ab = compare_versions(&va, &vb);
            let ba = compare_versions(&vb, &va);
            prop_assert_eq!(i16::from(ab), -i16::from(ba));
        }

        // r[verify nix-version.compare-versions]
        #[test]
        fn prop_compare_range(
            a in "[0-9a-z.]{1,10}",
            b in "[0-9a-z.]{1,10}",
        ) {
            let r = compare_versions(&a.into_bytes(), &b.into_bytes());
            prop_assert!(r == -1 || r == 0 || r == 1);
        }

        // r[verify nix-version.parse-drv-name]
        #[test]
        fn prop_parse_drv_name_in_range(
            s in "[a-z]{1,10}(-[0-9a-z.]{1,10})?",
        ) {
            let v = s.into_bytes();
            let idx = parse_drv_name(&v);
            prop_assert!(idx <= v.len());
        }

        // P0: transitivity — if a<=b and b<=c then a<=c
        #[test]
        fn prop_compare_transitive(
            a in "[0-9a-z.]{1,8}",
            b in "[0-9a-z.]{1,8}",
            c in "[0-9a-z.]{1,8}",
        ) {
            let va = a.into_bytes();
            let vb = b.into_bytes();
            let vc = c.into_bytes();
            let ab = compare_versions(&va, &vb);
            let bc = compare_versions(&vb, &vc);
            let ac = compare_versions(&va, &vc);
            if ab <= 0 && bc <= 0 {
                prop_assert!(ac <= 0);
            }
            if ab >= 0 && bc >= 0 {
                prop_assert!(ac >= 0);
            }
        }

        // P0: large version strings (50+ components) — stress fuel bound
        #[test]
        fn prop_compare_large_versions(
            components in proptest::collection::vec(0u32..100, 50..80),
        ) {
            let version: String = components.iter()
                .map(std::string::ToString::to_string)
                .collect::<Vec<_>>()
                .join(".");
            let v = version.into_bytes();
            prop_assert_eq!(compare_versions(&v, &v), 0);
        }

        // P0: all-separator strings behave like empty
        #[test]
        fn prop_compare_empty_separators(
            seps in "[.\\-]{0,10}",
        ) {
            let v = seps.into_bytes();
            let empty: Vec<u8> = Vec::new();
            prop_assert_eq!(compare_versions(&v, &empty), 0);
            prop_assert_eq!(compare_versions(&v, &v), 0);
        }

        // P0: overflow-length numeric components — reflexivity still holds
        #[test]
        fn prop_compare_overflow_reflexive(
            big in "[1-9][0-9]{18,20}",
        ) {
            let v = big.into_bytes();
            prop_assert_eq!(compare_versions(&v, &v), 0);
        }
    }

    // P0: concrete Nix version corpus — antisymmetry and known orderings
    #[test]
    fn test_nix_version_corpus() {
        let versions = [
            "2.3.1", "2.3.10", "2.3.2", "2.4", "2.13.3", "23.05", "23.11", "24.05", "1.0pre1", "1.0pre2", "1.0", "0.1",
            "0.10", "0.2",
        ];
        for &a in &versions {
            for &b in &versions {
                let va = a.as_bytes().to_vec();
                let vb = b.as_bytes().to_vec();
                let ab = compare_versions(&va, &vb);
                let ba = compare_versions(&vb, &va);
                assert_eq!(i16::from(ab), -i16::from(ba), "antisymmetry failed for {a} vs {b}");
            }
            let va = a.as_bytes().to_vec();
            assert_eq!(compare_versions(&va, &va), 0, "reflexivity failed for {a}");
        }
        // Known orderings
        assert_eq!(compare_versions(&v("2.3.1"), &v("2.3.10")), -1);
        assert_eq!(compare_versions(&v("2.3.2"), &v("2.3.10")), -1);
        assert_eq!(compare_versions(&v("23.05"), &v("23.11")), -1);
        assert_eq!(compare_versions(&v("0.1"), &v("0.2")), -1);
        assert_eq!(compare_versions(&v("0.2"), &v("0.10")), -1);
    }
}
