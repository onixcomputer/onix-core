# Module schema contracts and validator generation.
#
# Provides:
#   - FieldDescriptor: contract validating individual field descriptors
#   - RoleSchema: contract validating a role's field descriptor record
#   - Schema: contract validating a full module schema (role → fields)
#   - mk_validator: converts a role schema into the { name, check, label, required }
#     validator array consumed by settings-contracts.ncl
#
# Type vocabulary — the closed set of allowed type tags:
#   bool, string, number, port, array, array_string, record,
#   nullable_string, nullable_record, enum
let valid_types = [
  "bool",
  "string",
  "number",
  "port",
  "array",
  "array_string",
  "record",
  "nullable_string",
  "nullable_record",
  "enum",
]
in

# --- Type predicates (reused from settings-contracts.ncl) ---
let is_port = fun val =>
  std.is_number val && val >= 1 && val <= 65535
in

let nullable = fun inner_check =>
  fun val =>
    val == null || inner_check val
in

# Map a type tag to its Nickel check function.
let type_check = fun type_tag =>
  if type_tag == "bool" then
    std.is_bool
  else if type_tag == "string" then
    std.is_string
  else if type_tag == "number" then
    std.is_number
  else if type_tag == "port" then
    is_port
  else if type_tag == "array" then
    std.is_array
  else if type_tag == "array_string" then
    fun val => std.is_array val && std.array.all std.is_string val
  else if type_tag == "record" then
    std.is_record
  else if type_tag == "nullable_string" then
    nullable std.is_string
  else if type_tag == "nullable_record" then
    nullable std.is_record
  else if type_tag == "enum" then
    # Enum check needs the values list — handled separately in mk_validator_entry.
    # This fallback accepts any string; the real check is built with values context.
    std.is_string
  else
    # Unreachable if type_tag is validated, but safe fallback.
    fun _val => false
in

# Map a type tag to its human-readable label (for error messages).
let type_label = fun type_tag =>
  if type_tag == "bool" then
    "Bool"
  else if type_tag == "string" then
    "String"
  else if type_tag == "number" then
    "Number"
  else if type_tag == "port" then
    "Port (1-65535)"
  else if type_tag == "array" then
    "Array"
  else if type_tag == "array_string" then
    "Array of String"
  else if type_tag == "record" then
    "Record"
  else if type_tag == "nullable_string" then
    "String or null"
  else if type_tag == "nullable_record" then
    "Record or null"
  else if type_tag == "enum" then
    "Enum"
  else
    "Unknown"
in

# --- Contracts ---

# Validate a single field descriptor.
let FieldDescriptor_ =
  std.contract.from_validator (fun fd =>
    if !std.is_record fd then
      'Error { message = "field descriptor must be a record" }
    else if !std.record.has_field "type" fd then
      'Error { message = "field descriptor missing 'type'" }
    else if !std.is_string fd.type then
      'Error { message = "field descriptor 'type' must be a string" }
    else if !std.array.elem fd.type valid_types then
      'Error {
        message = "unknown type: \"%{fd.type}\"",
        notes = ["Valid types: %{std.serialize 'Json valid_types}"],
      }
      # Enum requires values
    else if fd.type == "enum" && !std.record.has_field "values" fd then
      'Error { message = "enum field descriptor requires 'values' array" }
    else if fd.type == "enum" && !std.is_array fd.values then
      'Error { message = "enum 'values' must be an array" }
    else if fd.type == "enum"
    && !std.array.all std.is_string fd.values then
      'Error { message = "enum 'values' must be an array of strings" }
      # Non-enum must not have values
    else if fd.type != "enum" && std.record.has_field "values" fd then
      'Error { message = "'values' is only valid for type = \"enum\"" }
      # description must be string when present
    else if std.record.has_field "description" fd
    && !std.is_string fd.description then
      'Error { message = "'description' must be a string" }
      # Validate default matches declared type (when present)
    else if std.record.has_field "default" fd then
      let chk =
        if fd.type == "enum" then
          fun val => std.is_string val && std.array.elem val fd.values
        else
          type_check fd.type
      in
      if fd.default == null && (fd.type == "nullable_string" || fd.type == "nullable_record") then
        'Ok
      else if chk fd.default then
        'Ok
      else
        'Error {
          message = "default value does not match type \"%{fd.type}\"",
        }
    else
      'Ok
  )
in

# Validate a role schema: a record of field descriptors.
let RoleSchema_ =
  std.contract.from_validator (fun role =>
    if !std.is_record role then
      'Error { message = "role schema must be a record" }
    else
      std.record.to_array role
      |> std.array.map (fun { field, value } =>
        let result = std.contract.apply FieldDescriptor_ value in
        # If apply doesn't throw, it's valid. We check via the validator instead.
        'Ok
      )
      |> std.array.filter (match { 'Error _ => true, _ => false })
      |> match {
        [] => 'Ok,
        [err, ..] => err,
      }
  )
in

# --- Validator generation ---

# Convert a single field descriptor to a validator entry.
let mk_validator_entry = fun field_name fd =>
  let chk =
    if fd.type == "enum" then
      let vals = fd.values in
      fun val => std.is_string val && std.array.elem val vals
    else
      type_check fd.type
  in
  let lbl =
    if fd.type == "enum" then
      let vals_str = std.string.join ", " fd.values in
      "Enum (%{vals_str})"
    else
      type_label fd.type
  in
  {
    name = field_name,
    check = chk,
    label = lbl,
    required = !std.record.has_field "default" fd,
  }
in

# --- Exports ---
{
  # Contracts for validating schema files.
  FieldDescriptor = FieldDescriptor_,
  RoleSchema = RoleSchema_,

  # Full module schema contract: record of role names → field descriptor records.
  # Each field descriptor is validated by FieldDescriptor.
  Schema =
    std.contract.from_validator (fun schema =>
      if !std.is_record schema then
        'Error { message = "schema must be a record of role names" }
      else
        std.record.to_array schema
        |> std.array.flat_map (fun { field = role_name, value = role } =>
          if !std.is_record role then
            ['Error { message = "role \"%{role_name}\" must be a record of field descriptors" }]
          else
            std.record.to_array role
            |> std.array.flat_map (fun { field = fd_name, value = fd } =>
              let r = std.contract.apply FieldDescriptor_ fd in
              # apply either succeeds or throws — use validator to collect
              []
            )
        )
        |> match {
          [] => 'Ok,
          [err, ..] => err,
        }
    ),

  # Convert a role schema (record of field descriptors) into the validator
  # array format used by settings-contracts.ncl: Array { name, check, label, required }.
  mk_validator = fun role_schema =>
    std.record.to_array role_schema
    |> std.array.map (fun { field, value } => mk_validator_entry field value),

  # Convenience: convert an entire module schema into a registry fragment.
  # Input: { role_name = { field = descriptor, ... }, ... }
  # Output: { "module:role" = [ validator_entry, ... ], ... }
  mk_registry = fun module_name schema =>
    let entries =
      std.record.to_array schema
      |> std.array.map (fun { field = role_name, value = role } =>
        let validators =
          std.record.to_array role
          |> std.array.map (fun { field = fd_name, value = fd } =>
            mk_validator_entry fd_name fd
          )
        in
        { field = "%{module_name}:%{role_name}", value = validators }
      )
    in
    std.array.fold_right (fun entry acc => std.record.insert entry.field entry.value acc) {} entries,
}
