use nix_wasm_rust::Value;

// nix_wasm_init_v1 is exported by the nix-wasm-rust crate (linked into this cdylib).

/// Convert a serde_json::Value tree into a nix-wasm-rust Value.
fn json_to_nix(json: &serde_json::Value) -> Value {
    match json {
        serde_json::Value::Null => Value::make_null(),
        serde_json::Value::Bool(b) => Value::make_bool(*b),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                Value::make_int(i)
            } else {
                Value::make_float(n.as_f64().unwrap_or(0.0))
            }
        }
        serde_json::Value::String(s) => Value::make_string(s),
        serde_json::Value::Array(arr) => {
            let items: Vec<Value> = arr.iter().map(json_to_nix).collect();
            Value::make_list(&items)
        }
        serde_json::Value::Object(map) => {
            let pairs: Vec<(String, Value)> = map
                .iter()
                .map(|(k, v)| (k.clone(), json_to_nix(v)))
                .collect();
            let refs: Vec<(&str, Value)> = pairs.iter().map(|(k, v)| (k.as_str(), *v)).collect();
            Value::make_attrset(&refs)
        }
    }
}

/// Evaluate a Nickel source string, returning the result as a Nix value.
///
/// The argument must be a Nix string containing valid Nickel source code.
/// The full Nickel standard library is available during evaluation.
/// The result is fully evaluated and converted to a Nix value (attrset, list,
/// string, number, bool, or null) via a JSON round-trip.
#[no_mangle]
pub extern "C" fn evalNickel(arg: Value) -> Value {
    let source = arg.get_string();
    eval_nickel_source(&source)
}

fn eval_nickel_source(source: &str) -> Value {
    use nickel_lang_core::{
        error::NullReporter,
        eval::cache::CacheImpl,
        program::Program,
        serialize::{self, ExportFormat},
    };
    use std::io::Cursor;

    let reader = Cursor::new(source.as_bytes());
    let mut program: Program<CacheImpl> =
        Program::new_from_source(reader, "<wasm>", std::io::sink(), NullReporter {})
            .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel I/O error: {e}")));

    let value = program
        .eval_full_for_export()
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel eval error: {e:?}")));

    let json_str = serialize::to_string(ExportFormat::Json, &value)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel serialize error: {e:?}")));

    let json: serde_json::Value = serde_json::from_str(&json_str)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("json parse error: {e}")));

    json_to_nix(&json)
}

/// Evaluate a Nickel file from a Nix path, returning the result as a Nix value.
///
/// The argument must be a Nix path pointing to a `.ncl` file. The file is
/// read via the host's `read_file` ABI (no std::fs access from WASM).
/// Nickel `import` statements within the file are not yet supported —
/// the file must be self-contained or use only the standard library.
#[no_mangle]
pub extern "C" fn evalNickelFile(arg: Value) -> Value {
    let contents = arg.read_file();
    let source = String::from_utf8(contents)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel file is not valid UTF-8: {e}")));
    eval_nickel_source(&source)
}
