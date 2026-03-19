use nix_wasm_rust::Value;

// nix_wasm_init_v1 is exported by the nix-wasm-rust crate (linked into this cdylib).

// ---------------------------------------------------------------------------
// Stdlib cache: parse/compile/transform the Nickel stdlib once per WASM
// instance lifetime, then clone_for_eval on each call. Saves ~184KB of
// LALRPOP parsing per invocation.
// ---------------------------------------------------------------------------

use std::cell::RefCell;
use std::sync::Arc;

use nickel_lang_core::cache::{CacheHub, InputFormat, SourceIO, SourcePath};
use nickel_lang_core::error::NullReporter;
use nickel_lang_core::eval::cache::CacheImpl;
use nickel_lang_core::eval::{VirtualMachine, VmContext};
use nickel_lang_core::position::PosTable;

/// Pre-prepared stdlib state: CacheHub with stdlib in both AstCache and
/// TermCache, plus the PosTable containing stdlib position indices.
/// The PosTable must be cloned alongside the CacheHub so that position
/// references in the cloned TermCache remain valid.
struct PreparedStdlib {
    cache: CacheHub,
    pos_table: PosTable,
}

thread_local! {
    static STDLIB_CACHE: RefCell<Option<PreparedStdlib>> = RefCell::new(None);
}

/// No-op SourceIO for string-based evaluations that don't need filesystem access.
/// All methods return errors — string eval never resolves imports.
struct NoopSourceIO;

impl SourceIO for NoopSourceIO {
    fn current_dir(&self) -> std::io::Result<std::path::PathBuf> {
        Err(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            "no filesystem in string eval mode",
        ))
    }

    fn read_to_string(&self, path: &std::path::Path) -> std::io::Result<String> {
        Err(std::io::Error::new(
            std::io::ErrorKind::Unsupported,
            format!(
                "cannot import '{}' in string eval mode — use evalNickelFile for file imports",
                path.display()
            ),
        ))
    }

    fn metadata_timestamp(
        &self,
        _path: &std::path::Path,
    ) -> std::io::Result<std::time::SystemTime> {
        Ok(std::time::SystemTime::UNIX_EPOCH)
    }
}

/// Get a CacheHub with the stdlib already prepared. On first call, creates
/// the cache and runs prepare_stdlib. On subsequent calls, returns
/// clone_for_eval() with the given IO provider swapped in.
fn get_prepared_cache(io: Arc<dyn SourceIO>) -> (CacheHub, PosTable) {
    STDLIB_CACHE.with(|cell| {
        let mut slot = cell.borrow_mut();
        if slot.is_none() {
            let mut cache = CacheHub::new();
            let mut pos_table = PosTable::new();
            cache
                .prepare_stdlib(&mut pos_table)
                .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("stdlib init failed: {e:?}")));
            *slot = Some(PreparedStdlib { cache, pos_table });
        }
        let prepared = slot.as_ref().unwrap();
        let mut cloned = prepared.cache.clone_for_eval();
        cloned.sources.io = io;
        (cloned, prepared.pos_table.clone())
    })
}

/// Core evaluation: add source to a prepared CacheHub, prepare without
/// typechecking, build VM with stdlib env from TermCache, evaluate, convert.
fn eval_with_cache(source: &str, cache: CacheHub, pos_table: PosTable) -> Value {
    use std::io::Cursor;
    use std::path::PathBuf;

    let mut cache = cache;
    let mut pos_table = pos_table;

    // Add user source to cache
    let main_id = cache
        .sources
        .add_source(
            SourcePath::Path(PathBuf::from("<wasm>"), InputFormat::Nickel),
            Cursor::new(source.as_bytes()),
        )
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel I/O error: {e}")));

    // Prepare user source only — no typecheck, no prepare_stdlib.
    // The cloned TermCache already has stdlib entries, so mk_eval_env
    // can build the initial environment without re-parsing the stdlib.
    cache
        .prepare_eval_only(&mut pos_table, main_id)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel prepare error: {e:?}")));

    // Build VmContext (moves cache in as import_resolver)
    let mut vm_ctxt: VmContext<CacheHub, CacheImpl> =
        VmContext::new_with_pos_table(cache, pos_table, std::io::sink(), NullReporter {});

    // Closurize the main term (needs eval cache from VmContext)
    vm_ctxt
        .import_resolver
        .closurize(&mut vm_ctxt.cache, main_id)
        .unwrap_or_else(|e| {
            nix_wasm_rust::panic(&format!("nickel closurize error: {e:?}"));
        });

    // Get the prepared term
    let prepared = vm_ctxt
        .import_resolver
        .terms
        .get_owned(main_id)
        .unwrap_or_else(|| nix_wasm_rust::panic("nickel: prepared term not found in cache"));

    // Create VM — mk_eval_env reads stdlib from TermCache — and evaluate
    let value = VirtualMachine::new(&mut vm_ctxt)
        .eval_full_for_export_closure(prepared.into())
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel eval error: {e:?}")));

    nickel_to_nix(&value)
}

/// Convert a fully-evaluated Nickel value directly to a Nix value.
///
/// Walks the NickelValue tree via `content_ref()` dispatch and builds
/// nix-wasm-rust Values without any intermediate JSON serialization.
/// Handles Null, Bool, Number, String, Array, and Record variants.
/// Panics on any non-data variant (functions, thunks, etc.).
fn nickel_to_nix(value: &nickel_lang_core::eval::value::NickelValue) -> Value {
    use nickel_lang_core::eval::value::{Container, ValueContentRef};

    match value.content_ref() {
        ValueContentRef::Null => Value::make_null(),
        ValueContentRef::Bool(b) => Value::make_bool(b),
        ValueContentRef::Number(n) => {
            use nickel_lang_core::term::{IsInteger, RoundingFrom, RoundingMode};
            if n.is_integer() {
                if let Ok(i) = i64::try_from(n) {
                    return Value::make_int(i);
                }
            }
            let f = f64::rounding_from(n, RoundingMode::Nearest).0;
            Value::make_float(f)
        }
        ValueContentRef::String(s) => Value::make_string(s),
        ValueContentRef::Array(Container::Empty) => Value::make_list(&[]),
        ValueContentRef::Array(Container::Alloc(arr)) => {
            let items: Vec<Value> = arr.array.iter().map(|v| nickel_to_nix(v)).collect();
            Value::make_list(&items)
        }
        ValueContentRef::Record(Container::Empty) => Value::make_attrset(&[]),
        ValueContentRef::Record(Container::Alloc(record)) => {
            let mut entries: Vec<(String, Value)> = record
                .iter_serializable()
                .map(|entry| {
                    let (id, val) = entry.unwrap_or_else(|e| {
                        nix_wasm_rust::panic(&format!(
                            "nickel_to_nix: missing field definition for `{}`",
                            e.id
                        ))
                    });
                    (id.to_string(), nickel_to_nix(val))
                })
                .collect();
            entries.sort_by(|(a, _), (b, _)| a.cmp(b));
            let refs: Vec<(&str, Value)> = entries.iter().map(|(k, v)| (k.as_str(), *v)).collect();
            Value::make_attrset(&refs)
        }
        ValueContentRef::EnumVariant(ev) if ev.arg.is_none() => Value::make_string(ev.tag.label()),
        other => nix_wasm_rust::panic(&format!(
            "nickel_to_nix: unexpected value variant after full eval: {other:?}"
        )),
    }
}

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

/// Evaluate a Nickel source string, returning the result as a Nix value.
///
/// The argument must be a Nix string containing valid Nickel source code.
/// The full Nickel standard library is available during evaluation.
/// The result is fully evaluated and converted to a Nix value (attrset, list,
/// string, number, bool, or null) via direct term walk.
#[no_mangle]
pub extern "C" fn evalNickel(arg: Value) -> Value {
    let source = arg.get_string();
    eval_nickel_source(&source)
}

fn eval_nickel_source(source: &str) -> Value {
    let (cache, pos_table) = get_prepared_cache(Arc::new(NoopSourceIO));
    eval_with_cache(source, cache, pos_table)
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
/// and return the result as a Nix value via direct term walk.
fn eval_nickel_file_source(source: &str, base_path: Value) -> Value {
    let io = Arc::new(WasmHostIO { base_path });
    let (cache, pos_table) = get_prepared_cache(io);
    eval_with_cache(source, cache, pos_table)
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
