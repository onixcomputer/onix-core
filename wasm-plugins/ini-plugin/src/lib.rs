use configparser::ini::Ini;
use nix_wasm_rust::Value;

/// Parse an INI string into a Nix attrset of sections.
///
/// Each section becomes an attrset of key-value pairs.
/// Keys without a section go under the "DEFAULT" key.
/// All values are strings (INI has no type system).
#[no_mangle]
pub extern "C" fn fromINI(arg: Value) -> Value {
    let input = arg.get_string();
    let mut config = Ini::new();
    config
        .read(input)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("INI parse error: {}", e)));

    let map = config.get_map_ref();
    let sections: Vec<(&str, Value)> = map
        .iter()
        .map(|(section, keys)| {
            let pairs: Vec<(&str, Value)> = keys
                .iter()
                .map(|(k, v)| {
                    let val = match v {
                        Some(s) => Value::make_string(s),
                        None => Value::make_null(),
                    };
                    (k.as_str(), val)
                })
                .collect();
            (section.as_str(), Value::make_attrset(&pairs))
        })
        .collect();

    Value::make_attrset(&sections)
}
