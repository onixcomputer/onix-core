# Service settings validation contracts — auto-derived from module schemas.
#
# Each module's schema.ncl defines field names, types, defaults, and
# descriptions. This file imports every schema and generates the
# validator registry via mk_validator from lib/schema-contracts.ncl.
#
# Adding a field to a module's schema.ncl automatically makes it
# validated here — no manual sync step.
let sc = import "../../lib/schema-contracts.ncl" in

# --- Module schema imports ---
let schemas = {
  "buildbot" = import "../../modules/buildbot/schema.ncl",
  "calibre-server" = import "../../modules/calibre-server/schema.ncl",
  "clankers" = import "../../modules/clankers/schema.ncl",
  "cloud-hypervisor-vm" = import "../../modules/cloud-hypervisor-vm/schema.ncl",
  "cloudflare-tunnel" = import "../../modules/cloudflare-tunnel/schema.ncl",
  "grafana" = import "../../modules/grafana/schema.ncl",
  "harmonia" = import "../../modules/harmonia/schema.ncl",
  "home-manager-profiles" = import "../../modules/home-manager-profiles/schema.ncl",
  "homepage-dashboard" = import "../../modules/homepage-dashboard/schema.ncl",
  "infinity" = import "../../modules/infinity/schema.ncl",
  "lemonade" = import "../../modules/lemonade/schema.ncl",
  "llamacpp-rpc" = import "../../modules/llamacpp-rpc/schema.ncl",
  "llm-agents" = import "../../modules/llm-agents/schema.ncl",
  "llm" = import "../../modules/llm/schema.ncl",
  "loki" = import "../../modules/loki/schema.ncl",
  "nix-gc" = import "../../modules/nix-gc/schema.ncl",
  "ollama" = import "../../modules/ollama/schema.ncl",
  "open-notebook" = import "../../modules/open-notebook/schema.ncl",
  "prometheus" = import "../../modules/prometheus/schema.ncl",
  "speaches" = import "../../modules/speaches/schema.ncl",
  "static-server" = import "../../modules/static-server/schema.ncl",
  "syncthing" = import "../../modules/syncthing/schema.ncl",
  "tailscale-traefik" = import "../../modules/tailscale-traefik/schema.ncl",
  "tailscale" = import "../../modules/tailscale/schema.ncl",
  "upmpdcli" = import "../../modules/upmpdcli/schema.ncl",
  "vaultwarden" = import "../../modules/vaultwarden/schema.ncl",
}
in

# --- Type name helper (for error messages) ---
let type_name = fun val =>
  if std.is_bool val then
    "Bool"
  else if std.is_number val then
    "Number"
  else if std.is_string val then
    "String"
  else if std.is_array val then
    "Array"
  else if std.is_record val then
    "Record"
  else if val == null then
    "Null"
  else
    "Unknown"
in

# --- Build the registry from schemas ---
let registry =
  std.record.to_array schemas
  |> std.array.flat_map (fun { field = mod_name, value = mod_schema } =>
    std.record.to_array mod_schema
    |> std.array.map (fun { field = role_name, value = role_schema } =>
      {
        field = "%{mod_name}:%{role_name}",
        value = sc.mk_validator role_schema,
      }
    )
  )
  |> std.array.fold_right
    (fun entry acc => std.record.insert entry.field entry.value acc)
    {}
in

{
  # Validate settings fields for a given module:role key.
  #
  # Args:
  #   key  — "module-name:role-name"
  #   path — human-readable location (e.g. "my-instance.roles.server")
  #   settings — the settings record to validate
  #
  # Returns: array of error message strings (empty = all OK)
  validate_fields = fun key path settings =>
    if std.record.has_field key registry then
      registry."%{key}"
      |> std.array.flat_map (fun { name, check, label, required } =>
        if std.record.has_field name settings then
          let val = settings."%{name}" in
          if check val then
            []
          else
            ["%{path}.settings.%{name}: expected %{label}, got %{type_name val}"]
        else if required then
          ["%{path}.settings.%{name}: required field missing (expected %{label})"]
        else
          []
      )
    else
      [],
}
