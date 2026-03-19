# Service instance contracts.
#
# Validates structural fields of service inventory entries:
# module names, inputs, tag references, machine references.
# Settings are freeform — NixOS modules validate at build time.
#
# Catches at `ncl export` time:
#   - Typos in module names, tags, or machine references
#   - Invalid module.input values
#   - References to machines not in the registry
let core = import "../core/contracts.ncl" in
let machines_data = import "../core/machines.ncl" in

let machine_names = std.record.fields machines_data.machines in

# Auto-computed tags (clan-core adds these; not manually assigned to machines)
let auto_tags = ["nixos", "darwin", "all"] in

# All valid tags for service targeting (manual + auto-computed)
let all_service_tags = std.array.flatten [core.allTags, auto_tags] in

# --- Module registries ---
let self_modules = [
  "buildbot",
  "calibre-server",
  "clankers",
  "clonadic",
  "cloudflare-tunnel",
  "grafana",
  "harmonia",
  "home-manager-profiles",
  "homepage-dashboard",
  "iroh-ssh",
  "llm",
  "llm-agents",
  "loki",
  "nix-gc",
  "ollama",
  "prometheus",
  "static-server",
  "tailscale",
  "tailscale-traefik",
  "upmpdcli",
  "vaultwarden",
]
in

let clan_core_modules = [
  "borgbackup",
  "matrix-synapse",
  "sshd",
  "trusted-nix-caches",
  "users",
]
in

let all_modules = std.array.flatten [self_modules, clan_core_modules] in

{
  ModuleName =
    std.contract.from_validator (match {
      value if std.is_string value && std.array.elem value all_modules => 'Ok,
      value if std.is_string value =>
        'Error {
          message = "unknown module: \"%{value}\"",
          notes = ["Valid modules: %{std.serialize 'Json all_modules}"],
        },
      _ => 'Error { message = "module name must be a string" },
    }
    ),

  ModuleInput =
    std.contract.from_validator (match {
      value if std.is_string value
        && std.array.elem value ["self", "clan-core"] => 'Ok,
      value if std.is_string value =>
        'Error {
          message = "module.input must be \"self\" or \"clan-core\", got \"%{value}\"",
        },
      _ => 'Error { message = "module.input must be a string" },
    }
    ),

  # Service instance shape (module fields validated, roles freeform)
  ServiceInstance = {
    module
      | {
        name | ModuleName,
        input | ModuleInput | optional,
      },
    roles | { _ : Dyn },
  },

  # Top-level services record
  Services = {
    instances | { _ : ServiceInstance },
  },

  # Cross-reference validator: checks all tag keys and machine keys
  # in every role against the registries.
  ValidateRefs =
    std.contract.from_validator (fun services =>
      let instances = services.instances in
      let errors =
        std.record.to_array instances
        |> std.array.flat_map (fun { field = inst_name, value = inst } =>
          std.record.to_array inst.roles
          |> std.array.flat_map (fun { field = role_name, value = role } =>
            let tag_errors =
              if std.record.has_field "tags" role && std.is_record role.tags then
                std.record.fields role.tags
                |> std.array.filter (fun t =>
                  !std.array.elem t all_service_tags
                )
                |> std.array.map (fun t =>
                  "%{inst_name}.roles.%{role_name}: unknown tag \"%{t}\""
                )
              else
                []
            in
            let machine_errors =
              if std.record.has_field "machines" role && std.is_record role.machines then
                std.record.fields role.machines
                |> std.array.filter (fun m =>
                  !std.array.elem m machine_names
                )
                |> std.array.map (fun m =>
                  "%{inst_name}.roles.%{role_name}: unknown machine \"%{m}\""
                )
              else
                []
            in
            std.array.flatten [tag_errors, machine_errors]
          )
        )
      in
      if std.array.length errors > 0 then
        'Error {
          message = std.string.join ", " errors,
          notes = ["Fix references in services.ncl"],
        }
      else
        'Ok
    ),
}
