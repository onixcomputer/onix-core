## Context

The nickel-plugin wasm module currently exports two functions: `evalNickel` (string input) and `evalNickelFile` (path input). Both take a single `Value` argument and return a `Value`. There is no mechanism to pass Nix-side context into the Nickel evaluation.

The `nix-wasm-rust` ABI already exposes full accessor/constructor coverage: `get_type`, `get_attr`, `get_attrset`, `get_list`, `get_string`, `get_int`, `get_float`, `get_bool`, and corresponding `make_*` functions. This means Nix values can be walked and reconstructed without new ABI work.

Nickel's `Program` API supports `add_field` or equivalent mechanisms to inject bindings into the evaluation environment before calling `eval_full_for_export`.

## Goals / Non-Goals

**Goals:**
- `evalNickelFileWith`: evaluate a `.ncl` file with a Nix attrset injected as a top-level `args` binding
- `evalNickelWith`: evaluate a Nickel source string with the same argument injection
- Support all Nix data types that have Nickel equivalents: int, float, bool, string, null, list, attrset (recursively)
- Wrappers in `lib/wasm.nix` with ergonomic signatures: `evalNickelFileWith path args` and `evalNickelWith source args`
- Flake checks covering argument passing for each type and nested structures

**Non-Goals:**
- Passing Nix functions or derivations into Nickel — only data values
- Passing Nix paths as path-typed values (they arrive as strings; the caller can `builtins.toString` if needed)
- Bidirectional callbacks (Nickel calling back into Nix) — separate future work
- Changes to `evalNickel` or `evalNickelFile` signatures

## Decisions

**Single attrset argument protocol.** The `With` variants take a single `Value` argument that is a Nix attrset with two keys: `source` (string) or `file` (path), and `args` (attrset). Alternative: two separate wasm function arguments. Rejected because `builtins.wasm` calls are single-argument (`function → Value → Value`), so the attrset packing happens at the Nix wrapper level anyway.

```nix
# lib/wasm.nix wrapper
evalNickelFileWith = path: args:
  builtins.wasm {
    path = "${plugins}/nickel_plugin.wasm";
    function = "evalNickelFileWith";
  } { file = path; inherit args; };
```

**Nix-to-Nickel conversion function.** A new `nix_to_nickel(value: Value) -> nickel_lang_core::term::RichTerm` function walks the Nix value tree using `get_type` dispatch and constructs Nickel terms directly. This is the inverse of the existing `json_to_nix`. It lives in `lib.rs` alongside the existing conversion code.

Type mapping:
| Nix type | Nickel term |
|----------|-------------|
| int | `Term::Num` (as `Number` from i64) |
| float | `Term::Num` (as `Number` from f64) |
| bool | `Term::Bool` |
| string | `Term::Str` |
| null | `Term::Null` |
| list | `Term::Array` |
| attrset | `Term::Record` |

**Injection point: merge with source.** The args record is injected by wrapping the user's Nickel source. For a file `config.ncl` with args `{ cores = 8 }`, the effective source becomes:

```nickel
let args = { cores = 8 } in
let __user = import "<original-file>" in
__user
```

Alternative considered: using Nickel's programmatic API to add fields to the evaluation environment. This couples tightly to nickel-lang-core internals that change between versions. The source-wrapping approach works with any Nickel version and is trivially testable.

Simpler alternative: the `.ncl` file is written as a function `fun args => ...` and the args are passed as a Nickel value to `Program::add_import_source` or similar. This is cleaner but requires understanding which Program API to use for argument binding. We'll investigate nickel-lang-core's `Program` API and use the most stable approach — if a clean programmatic injection exists, prefer it; otherwise fall back to source wrapping.

**The `.ncl` file is a function.** The convention is that parameterized `.ncl` files are functions:

```nickel
# sysctl-defaults.ncl
fun { cores, ramGB, .. } =>
  { "vm.min_free_kbytes" = if ramGB > 64 then 131072 else 65536 }
```

The plugin evaluates the file, gets a Nickel function value, applies the converted args record to it, then exports the result. If the file doesn't evaluate to a function (it's just data), the args are ignored and a warning is emitted via `nix_wasm_rust::warn!`.

## Risks / Trade-offs

**Nickel-lang-core term construction API stability.** Building `RichTerm` values directly ties us to nickel-lang-core's internal representation. Mitigation: the vendored fork pins the version; and the nix-to-nickel conversion is isolated in one function.

**Attrset key ordering.** Nix attrsets are sorted; Nickel records are not ordered. No semantic issue but round-trip tests should compare by value, not by serialization.

**Large argument attrsets.** Deep/wide Nix values are walked recursively. Stack overflow is theoretically possible for pathologically nested structures. Mitigation: WASM default stack is 1MB; real configs are shallow. Not worth iterative conversion for now.
