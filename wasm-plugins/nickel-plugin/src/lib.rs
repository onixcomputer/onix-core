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
        ValueContentRef::ForeignId(id) => {
            let id = *id;
            if id > u32::MAX as u64 {
                nix_wasm_rust::panic(&format!(
                    "nickel_to_nix: ForeignId({id}) exceeds u32::MAX — not a valid Nix ValueId"
                ));
            }
            Value::from_raw(id as u32)
        }
        ValueContentRef::EnumVariant(ev) if ev.arg.is_none() => Value::make_string(ev.tag.label()),
        other => nix_wasm_rust::panic(&format!(
            "nickel_to_nix: unexpected value variant after full eval: {other:?}"
        )),
    }
}

/// Convert a Nix value to a Nickel value, recursively.
///
/// Data types (string, int, float, bool, null) become native Nickel values.
/// Attrsets and lists are recursed into so that data-only structures can be
/// destructured on the Nickel side (backward compat with the old source-text
/// approach). Functions and paths become ForeignId(value_id as u64) -- opaque
/// handles that nickel_to_nix recovers on the way out.
///
/// get_type() is called on every value to classify it. For functions/paths
/// this is the ONLY host ABI call -- no further inspection occurs.
fn nix_to_nickel(nix_val: &Value) -> nickel_lang_core::eval::value::NickelValue {
    use nickel_lang_core::eval::value::NickelValue;
    use nickel_lang_core::identifier::LocIdent;
    use nickel_lang_core::term::Number;
    use nix_wasm_rust::Type;

    match nix_val.get_type() {
        Type::Null => NickelValue::null(),
        Type::Bool => NickelValue::bool_value_posless(nix_val.get_bool()),
        Type::Int => NickelValue::number_posless(nix_val.get_int()),
        Type::Float => {
            let n = Number::try_from(nix_val.get_float())
                .unwrap_or_else(|_| nix_wasm_rust::panic("nix_to_nickel: non-finite float"));
            NickelValue::number_posless(n)
        }
        Type::String => NickelValue::string_posless(nix_val.get_string()),
        Type::Attrs => {
            let attrs = nix_val.get_attrset();
            let field_values: Vec<(LocIdent, NickelValue)> = attrs
                .iter()
                .map(|(key, val)| (LocIdent::from(key.as_str()), nix_to_nickel(&val)))
                .collect();
            NickelValue::record_posless(
                nickel_lang_core::term::record::RecordData::with_field_values(field_values),
            )
        }
        Type::List => {
            let items = nix_val.get_list();
            let nickel_items: Vec<NickelValue> = items.iter().map(|v| nix_to_nickel(&v)).collect();
            NickelValue::array_posless(nickel_items.into_iter().collect(), Vec::new())
        }
        // Functions, paths: opaque handle. get_type() was the only call.
        // nickel_to_nix recovers the original Nix value via Value::from_raw.
        Type::Function | Type::Path => NickelValue::foreign_id_posless(nix_val.raw_id() as u64),
    }
}

/// Convert a Nix args attrset to a Nickel record value.
fn nix_args_to_nickel_record(args: &Value) -> nickel_lang_core::eval::value::NickelValue {
    nix_to_nickel(args)
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

/// Parse a Nickel source string, apply it to a pre-built args record, and
/// evaluate. Used by evalNickelFileWith and evalNickelWith to avoid
/// serializing args to source text.
///
/// If `base_path` is Some, file imports resolve relative to that path.
/// If None, imports are not supported (string eval mode).
fn eval_nickel_apply_source(
    source: &str,
    args: nickel_lang_core::eval::value::NickelValue,
    base_path: Option<Value>,
) -> Value {
    use nickel_lang_core::eval::value::NickelValue;
    use nickel_lang_core::term::{AppData, Term};
    use std::io::Cursor;
    use std::path::PathBuf;

    let io: Arc<dyn SourceIO> = match base_path {
        Some(bp) => Arc::new(WasmHostIO { base_path: bp }),
        None => Arc::new(NoopSourceIO),
    };
    let (mut cache, mut pos_table) = get_prepared_cache(io);

    // Add user source to cache
    let main_id = cache
        .sources
        .add_source(
            SourcePath::Path(PathBuf::from("<wasm>"), InputFormat::Nickel),
            Cursor::new(source.as_bytes()),
        )
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel I/O error: {e}")));

    // Prepare user source (parse, transform, closurize stdlib)
    cache
        .prepare_eval_only(&mut pos_table, main_id)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel prepare error: {e:?}")));

    // Build VmContext
    let mut vm_ctxt: nickel_lang_core::eval::VmContext<
        CacheHub,
        nickel_lang_core::eval::cache::CacheImpl,
    > = nickel_lang_core::eval::VmContext::new_with_pos_table(
        cache,
        pos_table,
        std::io::sink(),
        nickel_lang_core::error::NullReporter {},
    );

    // Closurize main term
    vm_ctxt
        .import_resolver
        .closurize(&mut vm_ctxt.cache, main_id)
        .unwrap_or_else(|e| {
            nix_wasm_rust::panic(&format!("nickel closurize error: {e:?}"));
        });

    // Get the parsed function
    let parsed_fn = vm_ctxt
        .import_resolver
        .terms
        .get_owned(main_id)
        .unwrap_or_else(|| nix_wasm_rust::panic("nickel: prepared term not found in cache"));

    // Build application: (<parsed_fn>) <args_record>
    let app = NickelValue::term_posless(Term::App(AppData {
        head: parsed_fn.into(),
        arg: args,
    }));

    // Evaluate
    let value = nickel_lang_core::eval::VirtualMachine::new(&mut vm_ctxt)
        .eval_full_for_export_closure(app.into())
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("nickel eval error: {e:?}")));

    nickel_to_nix(&value)
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
/// Args are recursively converted to native Nickel values (records, arrays,
/// strings, numbers, bools, null). Non-data Nix values (functions, paths,
/// derivations) pass through as opaque ForeignId handles.
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

    let args_record = nix_args_to_nickel_record(&args_val);
    eval_nickel_apply_source(&file_source, args_record, Some(file_val))
}

/// Evaluate a Nickel source string with Nix arguments applied.
///
/// The argument must be a Nix attrset with keys:
///   - `source`: a Nickel source string (must evaluate to a function)
///   - `args`: a Nix attrset of arguments to pass to the function
///
/// The source should be a function: `fun { key1, key2, .. } => ...`
/// Args are converted to a Nickel record programmatically.
#[no_mangle]
pub extern "C" fn evalNickelWith(arg: Value) -> Value {
    let source_val = arg
        .get_attr("source")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelWith: missing 'source' attribute"));
    let args_val = arg
        .get_attr("args")
        .unwrap_or_else(|| nix_wasm_rust::panic("evalNickelWith: missing 'args' attribute"));

    let user_source = source_val.get_string();
    let args_record = nix_args_to_nickel_record(&args_val);
    eval_nickel_apply_source(&user_source, args_record, None)
}
