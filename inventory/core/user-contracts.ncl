# User instance contracts.
#
# Validates structural fields of user inventory entries:
# tag references, machine references, and profile names.
# Settings are freeform — NixOS modules validate at build time.
#
# Separated from core contracts.ncl to avoid circular imports
# (core/contracts.ncl <- machines.ncl <- core/contracts.ncl).
# Mirrors the pattern in services/contracts.ncl.
let core = import "contracts.ncl" in
let machines_data = import "machines.ncl" in

let machine_names = std.record.fields machines_data.machines in

# Auto-computed tags that are valid for role targeting
let auto_tags = ["nixos", "darwin", "all"] in
let all_service_tags = std.array.flatten [core.allTags, auto_tags] in

{
  ValidateUserRefs =
    std.contract.from_validator (fun users =>
      let instances = users.instances in
      let errors =
        std.record.to_array instances
        |> std.array.flat_map (fun { field = inst_name, value = inst } =>
          std.record.to_array inst.roles
          |> std.array.flat_map (fun { field = role_name, value = role } =>
            let tag_errors =
              if std.record.has_field "tags" role && std.is_record role.tags then
                std.record.fields role.tags
                |> std.array.filter (fun t => !std.array.elem t all_service_tags)
                |> std.array.map (fun t =>
                  "%{inst_name}.roles.%{role_name}: unknown tag \"%{t}\""
                )
              else
                []
            in
            let machine_errors =
              if std.record.has_field "machines" role && std.is_record role.machines then
                std.record.fields role.machines
                |> std.array.filter (fun m => !std.array.elem m machine_names)
                |> std.array.map (fun m =>
                  "%{inst_name}.roles.%{role_name}: unknown machine \"%{m}\""
                )
              else
                []
            in
            let profile_errors =
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
                []
            in
            std.array.flatten [tag_errors, machine_errors, profile_errors]
          )
        )
      in
      if std.array.length errors > 0 then
        'Error {
          message = std.string.join ", " errors,
          notes = ["Fix references in users.ncl"],
        }
      else
        'Ok
    ),
}
