# User instance contracts.
#
# Validates structural fields of user inventory entries:
# tag references, machine references, and profile names.
# Settings are freeform — NixOS modules validate at build time.
#
# Separated from core contracts.ncl to avoid circular imports
# (core/contracts.ncl ← machines.ncl ← core/contracts.ncl).
# Mirrors the pattern in services/contracts.ncl.
let core = import "contracts.ncl" in
let machines_data = import "machines.ncl" in

let machine_names = std.record.fields machines_data.machines in

{
  ValidateUserRefs =
    core.mkRefValidator {
      valid_tags = core.allServiceTags,
      valid_machines = machine_names,
      error_notes = ["Fix references in users.ncl"],
      extra_role_errors = fun inst_name role_name role =>
        if std.record.has_field "settings" role
        && std.is_record role.settings
        && std.record.has_field "profiles" role.settings then
          role.settings.profiles
          |> std.array.filter (fun p =>
            !std.array.elem p core.profileNames
          )
          |> std.array.map (fun p =>
            "%{inst_name}.roles.%{role_name}: unknown profile \"%{p}\""
          )
        else
          [],
    },
}
