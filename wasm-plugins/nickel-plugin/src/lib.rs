use nix_wasm_rust::Value;

// nix_wasm_init_v1 is exported by the nix-wasm-rust crate (linked into this cdylib).

/// Convert a Nix value to Nickel source text.
///
/// Walks the Nix value tree via `get_type()` dispatch and produces a string
/// that is valid Nickel syntax. Supports int, float, bool, string, null,
/// list (→ array), and attrset (→ record). Panics on unsupported types
/// (function, path).
fn nix_to_nickel_source(value: &Value) -> String {
    use nix_wasm_rust::Type;

    match value.get_type() {
        Type::Null => "null".to_string(),
        Type::Bool => {
            if value.get_bool() {
                "true".to_string()
            } else {
                "false".to_string()
            }
        }
        Type::Int => format!("{}", value.get_int()),
        Type::Float => {
            let f = value.get_float();
            // Nickel needs a decimal point for floats
            if f.fract() == 0.0 {
                format!("{f:.1}")
            } else {
                format!("{f}")
            }
        }
        Type::String => {
            let s = value.get_string();
            // Use Nickel multiline string m%" ... "% to avoid escaping issues
            format!("m%\"{s}\"%")
        }
        Type::List => {
            let items = value.get_list();
            let inner: Vec<String> = items.iter().map(|v| nix_to_nickel_source(v)).collect();
            format!("[{}]", inner.join(", "))
        }
        Type::Attrs => {
            let attrs = value.get_attrset();
            if attrs.is_empty() {
                return "{}".to_string();
            }
            let fields: Vec<String> = attrs
                .iter()
                .map(|(k, v)| {
                    let nickel_key = if needs_quoting(k) {
                        format!("\"{k}\"")
                    } else {
                        k.clone()
                    };
                    format!("{nickel_key} = {}", nix_to_nickel_source(v))
                })
                .collect();
            format!("{{ {} }}", fields.join(", "))
        }
        Type::Path => nix_wasm_rust::panic(
            "nix_to_nickel_source: cannot convert Nix path to Nickel — \
             use builtins.toString on the Nix side first",
        ),
        Type::Function => nix_wasm_rust::panic(
            "nix_to_nickel_source: cannot convert Nix function to Nickel — \
             only data values (int, float, bool, string, null, list, attrset) are supported",
        ),
    }
}

/// Check whether a Nickel record field name needs quoting.
fn needs_quoting(s: &str) -> bool {
    if s.is_empty() {
        return true;
    }
    // Nickel identifiers: start with letter or _, then letters/digits/_/-
    let mut chars = s.chars();
    let first = chars.next().unwrap();
    if !first.is_ascii_alphabetic() && first != '_' {
        return true;
    }
    for c in chars {
        if !c.is_ascii_alphanumeric() && c != '_' && c != '-' {
            return true;
        }
    }
    // Nickel keywords
    matches!(
        s,
        "if" | "then"
            | "else"
            | "let"
            | "in"
            | "fun"
            | "import"
            | "match"
            | "null"
            | "true"
            | "false"
            | "forall"
    )
}

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

/// IO provider that routes filesystem operations through the nix-wasm host ABI.
///
/// `current_dir()` returns the parent directory of the base file path.
/// `read_to_string()` uses `Value::make_path()` + `Value::read_file()`.
/// `metadata_timestamp()` returns `UNIX_EPOCH` (Nix store paths are immutable).
struct WasmHostIO {
    base_path: Value,
}

impl nickel_lang_core::cache::SourceIO for WasmHostIO {
    fn current_dir(&self) -> std::io::Result<std::path::PathBuf> {
        let full = self.base_path.get_path();
        Ok(full.parent().unwrap_or(&full).to_owned())
    }

    fn read_to_string(&self, path: &std::path::Path) -> std::io::Result<String> {
        let path_str = path.to_str().unwrap_or_default();
        let nix_path = self.base_path.make_path(path_str);
        let bytes = nix_path.read_file();
        String::from_utf8(bytes)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))
    }

    fn metadata_timestamp(
        &self,
        _path: &std::path::Path,
    ) -> std::io::Result<std::time::SystemTime> {
        // Nix store paths are immutable — no staleness possible.
        Ok(std::time::SystemTime::UNIX_EPOCH)
    }
}

/// Shared helper: evaluate Nickel source with WasmHostIO-backed import resolution
/// and return the result as a Nix value via the JSON round-trip.
fn eval_nickel_file_source(source: &str, base_path: Value) -> Value {
    use nickel_lang_core::{
        cache::CacheHub,
        error::NullReporter,
        eval::cache::CacheImpl,
        program::{Input, Program},
        serialize::{self, ExportFormat},
    };
    use std::io::Cursor;
    use std::sync::Arc;

    let io = Arc::new(WasmHostIO { base_path });
    let cache = CacheHub::with_io(io);

    let reader = Cursor::new(source.as_bytes());
    let input = Input::Source(
        reader,
        "<wasm>",
        nickel_lang_core::cache::InputFormat::Nickel,
    );

    let mut program: Program<CacheImpl> =
        Program::new_from_input_with_cache(input, cache, std::io::sink(), NullReporter {})
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
/// Relative `import` statements are supported — imported files are resolved
/// relative to the input file's directory via the host ABI.
#[no_mangle]
pub extern "C" fn evalNickelFile(arg: Value) -> Value {
    let contents = arg.read_file();
    let source = String::from_utf8(contents)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel file is not valid UTF-8: {e}")));

    eval_nickel_file_source(&source, arg)
}

/// Evaluate a Nickel file with Nix arguments applied.
///
/// The argument must be a Nix attrset with keys:
///   - `file`: a Nix path to a `.ncl` file (must evaluate to a function)
///   - `args`: a Nix attrset of arguments to pass to the function
///
/// The `.ncl` file should be a function: `fun { key1, key2, .. } => ...`
/// The args attrset is converted to Nickel source and applied as the argument.
/// If the file is not a function, a warning is emitted and the file's value
/// is returned with args ignored.
#[no_mangle]
pub extern "C" fn evalNickelFileWith(arg: Value) -> Value {
    let file_val = arg
        .get_attr("file")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelFileWith: missing 'file' attribute"));
    let args_val = arg
        .get_attr("args")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelFileWith: missing 'args' attribute"));

    let contents = file_val.read_file();
    let file_source = String::from_utf8(contents)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel file is not valid UTF-8: {e}")));

    let args_source = nix_to_nickel_source(&args_val);

    // Wrap: apply the file's function to the args
    // `(<file-contents>) <args>` — if the file is `fun {x, ..} => ...`, this applies it.
    let wrapped = format!("({file_source}) {args_source}");

    eval_nickel_file_source(&wrapped, file_val)
}

/// Evaluate a Nickel source string with Nix arguments applied.
///
/// The argument must be a Nix attrset with keys:
///   - `source`: a Nickel source string (must evaluate to a function)
///   - `args`: a Nix attrset of arguments to pass to the function
///
/// The source should be a function: `fun { key1, key2, .. } => ...`
/// The args attrset is converted to Nickel source and applied as the argument.
#[no_mangle]
pub extern "C" fn evalNickelWith(arg: Value) -> Value {
    let source_val = arg
        .get_attr("source")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelWith: missing 'source' attribute"));
    let args_val = arg
        .get_attr("args")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelWith: missing 'args' attribute"));

    let user_source = source_val.get_string();
    let args_source = nix_to_nickel_source(&args_val);

    let wrapped = format!("({user_source}) {args_source}");
    eval_nickel_source(&wrapped)
}
