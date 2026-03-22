## Context

The current Nickel-to-Nix conversion in `nickel-plugin` goes through three stages:

1. `program.eval_full_for_export()` → `RichTerm` (Nickel's fully-evaluated AST)
2. `serialize::to_string(ExportFormat::Json, &value)` → `String` (JSON text)
3. `serde_json::from_str(&json_str)` → `serde_json::Value` → `json_to_nix` → `nix_wasm_rust::Value`

Stages 2 and 3 exist because the original plugin was written incrementally — JSON was the easiest serialization to get working. Now that the plugin is stable, the intermediate JSON can be eliminated.

## Goals / Non-Goals

**Goals:**
- Replace the JSON round-trip with direct `RichTerm` → `nix_wasm_rust::Value` conversion
- Remove `serde_json` from `nickel-plugin`'s dependencies
- All existing flake checks pass without modification (behavior-preserving)
- Reduce allocations and binary size

**Non-Goals:**
- Changing the external API or behavior of any exported function
- Performance benchmarking (the improvement is architectural cleanliness; measurable perf gains are a bonus)
- Supporting Nickel types that aren't already handled (functions, enums-as-enums)

## Decisions

**Direct pattern match on `Term` variants.** After `eval_full_for_export`, the `RichTerm` is fully reduced. The new `richterm_to_nix` function matches on the inner `Term`:

```rust
fn richterm_to_nix(term: &RichTerm) -> Value {
    match term.term.as_ref() {
        Term::Null => Value::make_null(),
        Term::Bool(b) => Value::make_bool(*b),
        Term::Num(n) => {
            let f = n.to_f64();
            if f.fract() == 0.0 && f.abs() < (i64::MAX as f64) {
                Value::make_int(f as i64)
            } else {
                Value::make_float(f)
            }
        }
        Term::Str(s) => Value::make_string(s.as_str()),
        Term::Array(arr, _) => {
            let items: Vec<Value> = arr.iter().map(richterm_to_nix).collect();
            Value::make_list(&items)
        }
        Term::Record(data) | Term::RecRecord(data, ..) => {
            // Walk fields, skip internal metadata
            let pairs: Vec<(&str, Value)> = data.fields.iter()
                .filter(|(_, field)| field.value.is_some())
                .map(|(k, field)| {
                    (k.label(), richterm_to_nix(field.value.as_ref().unwrap()))
                })
                .collect();
            Value::make_attrset(&pairs)
        }
        other => nix_wasm_rust::panic(
            &format!("richterm_to_nix: unexpected term variant after full eval: {other:?}")
        ),
    }
}
```

**Nickel `Num` to Nix int/float heuristic.** Nickel uses a single `Number` type (arbitrary precision rational). Nix distinguishes `int` and `float`. The heuristic: if the number has no fractional part and fits in i64, emit int; otherwise emit float. This matches the existing JSON round-trip behavior (JSON integers become Nix ints via `serde_json::Number::as_i64`).

**Remove serde_json dependency entirely.** After the conversion, nothing in nickel-plugin uses serde_json. Removing it shrinks the wasm binary and reduces compile times. The `json_to_nix` function and all JSON-related imports are deleted.

**All exported functions use the same conversion.** `evalNickel`, `evalNickelFile`, and any future `With`/`validate` variants all call `richterm_to_nix` instead of the JSON pipeline. Single code path, single place to fix if Nickel's term representation changes.

## Risks / Trade-offs

**Coupling to nickel-lang-core internals.** `Term` variant names, `RecordData` field names, and `Number::to_f64()` are internal APIs. Mitigation: we vendor nickel-lang-core already, so we control the version. The conversion function is ~30 lines and easy to update.

**Edge cases in Number conversion.** Very large Nickel numbers (beyond i64 range) or rationals with exact decimal representations might convert differently than the JSON path. Mitigation: add a flake check for large numbers and fractional values. In practice, NixOS configs use small integers.

**Unexpected term variants.** If `eval_full_for_export` ever returns a non-data term (e.g., `Term::Lbl`, `Term::Contract`), the match arm panics. This is correct — these shouldn't appear after full evaluation — but the error message should be clear. The catch-all arm includes the debug representation of the term.
