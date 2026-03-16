use nix_wasm_rust::{Type, Value};
use yaml_rust2::{Yaml, YamlEmitter, YamlLoader};

fn yaml_to_value(yaml: &Yaml) -> Value {
    match yaml {
        Yaml::Real(_) => Value::make_float(yaml.as_f64().expect("YAML floating point number")),
        Yaml::Integer(n) => Value::make_int(*n),
        Yaml::String(s) => Value::make_string(s),
        Yaml::Boolean(b) => Value::make_bool(*b),
        Yaml::Array(array) => {
            Value::make_list(&array.iter().map(yaml_to_value).collect::<Vec<_>>())
        }
        Yaml::Hash(hash) => Value::make_attrset(
            &hash
                .iter()
                .map(|(key, value)| {
                    let key: &str = match &key {
                        Yaml::String(s) => s,
                        _ => nix_wasm_rust::panic(&format!(
                            "non-string YAML key not supported: {:?}",
                            key
                        )),
                    };
                    (key, yaml_to_value(value))
                })
                .collect::<Vec<_>>(),
        ),
        Yaml::Null => Value::make_null(),
        _ => nix_wasm_rust::panic(&format!("unsupported YAML value: {:?}", yaml)),
    }
}

/// Parse a YAML string into a Nix list of documents.
#[no_mangle]
pub extern "C" fn fromYAML(arg: Value) -> Value {
    let input = arg.get_string();
    let docs = YamlLoader::load_from_str(&input)
        .unwrap_or_else(|e| nix_wasm_rust::panic(&format!("YAML parse error: {}", e)));
    Value::make_list(&docs.iter().map(yaml_to_value).collect::<Vec<_>>())
}

fn value_to_yaml(v: Value) -> Yaml {
    match v.get_type() {
        Type::Int => Yaml::Integer(v.get_int()),
        Type::Float => Yaml::Real(format!("{}", v.get_float())),
        Type::Bool => Yaml::Boolean(v.get_bool()),
        Type::String => Yaml::String(v.get_string()),
        Type::Null => Yaml::Null,
        Type::Attrs => Yaml::Hash(
            v.get_attrset()
                .into_iter()
                .map(|(key, value)| (Yaml::String(key), value_to_yaml(value)))
                .collect(),
        ),
        Type::List => Yaml::Array(v.get_list().into_iter().map(value_to_yaml).collect()),
        t => nix_wasm_rust::panic(&format!("cannot serialize type {} to YAML", t as u64)),
    }
}

/// Serialize a Nix list of values into a YAML string (multi-document).
#[no_mangle]
pub extern "C" fn toYAML(arg: Value) -> Value {
    let mut out = String::new();
    for v in arg.get_list() {
        let yaml = value_to_yaml(v);
        let mut emitter = YamlEmitter::new(&mut out);
        emitter.dump(&yaml).unwrap();
        out.push('\n');
    }
    Value::make_string(&out)
}
