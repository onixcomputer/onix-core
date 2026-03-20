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

# --- Module registries ---
let self_modules = [
  "buildbot",
  "calibre-server",
  "clonadic",
  "cloudflare-tunnel",
  "grafana",
  "harmonia",
  "home-manager-profiles",
  "homepage-dashboard",
  "iroh-ssh",
  "llamacpp-rpc",
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
    core.mkRefValidator {
      valid_tags = core.allServiceTags,
      valid_machines = machine_names,
      error_notes = ["Fix references in services.ncl"],
      extra_role_errors = fun _inst _role _val => [],
    },
}
