# User inventory — source of truth.
#
# Defines user instances (password/groups) and home-manager profile
# assignments. Validated by Nickel contracts at export time.
#
# `profilesBasePath` is intentionally omitted — it's a Nix path that
# gets injected by inventory/core/default.nix after evaluation.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/core/users.ncl
#   3. Contracts check profile names, tags, machine refs — typos fail immediately
#   4. Commit .ncl
#
let contracts = import "contracts.ncl" in
let machines_data = import "machines.ncl" in

let machine_names = std.record.fields machines_data.machines in

# Auto-computed tags that are valid for role targeting
let auto_tags = ["nixos", "darwin", "all"] in
let all_service_tags = std.array.flatten [contracts.allTags, auto_tags] in

# --- Local contracts ---
let ValidateUserRefs =
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
                !std.array.elem p contracts.profileNames
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
  )
in

{
  instances = {

    # Password generation via upstream clan-core users module.
    # Groups are set here; UID, shell, and SSH keys are in tags/all.nix.
    user-brittonr = {
      module = { name = "users", input = "clan-core" },
      roles.default = {
        tags.nixos = {},
        settings = {
          user = "brittonr",
          prompt = true,
          groups = [
            "wheel",
            "networkmanager",
            "video",
            "audio",
            "input",
            "kvm",
            "docker",
            "dialout",
            "disk",
          ],
        },
      },
    },

    # Home-manager profiles per machine group.
    # Server/headless machines: base + dev
    hm-server = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        tags.hm-server = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev"],
        },
      },
    },

    # Laptop machines: base + dev + noctalia + social
    hm-laptop = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        tags.hm-laptop = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev", "noctalia", "social"],
        },
      },
    },

    # Desktop: base + dev + noctalia + creative + social + media
    hm-desktop = {
      module = { name = "home-manager-profiles", input = "self" },
      roles.default = {
        machines.britton-desktop = {},
        settings = {
          username = "brittonr",
          profiles = ["base", "dev", "noctalia", "creative", "social", "media"],
        },
      },
    },
  },
}
  | ValidateUserRefs
