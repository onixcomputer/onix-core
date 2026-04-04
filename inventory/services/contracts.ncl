# Service instance contracts.
#
# Validates structural fields of service inventory entries:
# module names, inputs, tag references, machine references,
# and settings types (via settings-contracts.ncl registry).
#
# Catches at `ncl export` time:
#   - Typos in module names, tags, or machine references
#   - Invalid module.input values
#   - References to machines not in the registry
#   - Type mismatches in settings fields
let core = import "../core/contracts.ncl" in
let machines_data = import "../core/machines.ncl" in
let sc = import "settings-contracts.ncl" in

let machine_names = std.record.fields machines_data.machines in

# --- Module registries ---
let self_modules = [
  "buildbot",
  "calibre-server",
  "clankers",
  "cloud-hypervisor-vm",
  "cloudflare-tunnel",
  "grafana",
  "harmonia",
  "home-manager-profiles",
  "homepage-dashboard",
  "lemonade",
  "llamacpp-rpc",
  "llm",
  "llm-agents",
  "loki",
  "nix-gc",
  "ollama",
  "prometheus",
  "static-server",
  "syncthing",
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
  # Exported for Nix flake checks (module-registry-sync).
  selfModules = self_modules,

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
    core.mkRefValidator {
      valid_tags = core.allServiceTags,
      valid_machines = machine_names,
      error_notes = ["Fix references in services.ncl"],
      extra_role_errors = fun _inst _role _val => [],
    },

  # Settings type validator: checks field types in each role's settings
  # against the registry in settings-contracts.ncl.
  # Handles settings at role level and under machines.<name>.
  ValidateSettings =
    std.contract.from_validator (fun data =>
      let instances = data.instances in
      let errors =
        std.record.to_array instances
        |> std.array.flat_map (fun { field = inst_name, value = inst } =>
          let mod_name = inst.module.name in
          std.record.to_array inst.roles
          |> std.array.flat_map (fun { field = role_name, value = role_val } =>
            let key = "%{mod_name}:%{role_name}" in
            # Settings at role level (e.g. roles.peer.settings = { ... })
            let role_errs =
              if std.record.has_field "settings" role_val
              && std.is_record role_val.settings then
                sc.validate_fields key "%{inst_name}.roles.%{role_name}" role_val.settings
              else
                []
            in
            # Settings under machines (e.g. roles.server.machines.aspen1.settings)
            let machine_errs =
              if std.record.has_field "machines" role_val
              && std.is_record role_val.machines then
                std.record.to_array role_val.machines
                |> std.array.flat_map (fun { field = mach_name, value = mach_val } =>
                  if std.is_record mach_val
                  && std.record.has_field "settings" mach_val
                  && std.is_record mach_val.settings then
                    sc.validate_fields
                      key
                      "%{inst_name}.roles.%{role_name}.machines.%{mach_name}"
                      mach_val.settings
                  else
                    []
                )
              else
                []
            in
            std.array.flatten [role_errs, machine_errs]
          )
        )
      in
      if std.array.length errors > 0 then
        'Error {
          message = std.string.join ", " errors,
          notes = ["Fix settings in services.ncl. See settings-contracts.ncl for expected types."],
        }
      else
        'Ok
    ),
}
