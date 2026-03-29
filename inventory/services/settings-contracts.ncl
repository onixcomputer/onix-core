# Service settings validation contracts.
#
# Maps (module-name, role-name) pairs to field specs that validate
# settings records at `ncl export` time. Catches typos and type
# mismatches before they reach the slow NixOS evaluation.
#
# Open-record strategy: only listed fields are checked. Unlisted
# fields pass through for NixOS modules to validate at build time.
# This means a typo on a non-contracted field won't be caught here,
# but the most common settings are covered.
#
# Maintenance: when a module adds or renames a setting that instances
# in services.ncl actually use, update the matching registry entry.
#
# Registry key format: "module-name:role-name"
# Each value is an array of { name, check, label } field specs.

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

# --- Common type predicates ---
let is_port = fun val =>
  std.is_number val && val >= 1 && val <= 65535
in

let nullable = fun inner_check =>
  fun val =>
    val == null || inner_check val
in

# --- Field spec builders ---
#
# Each returns { name, check, label } describing one expected field.
# `check` is a predicate: value → bool.
# `label` is the human-readable type shown in error messages.
let bool_field = fun n => { name = n, check = std.is_bool, label = "Bool" } in
let str_field = fun n => { name = n, check = std.is_string, label = "String" } in
let num_field = fun n => { name = n, check = std.is_number, label = "Number" } in
let port_field = fun n => { name = n, check = is_port, label = "Port (1-65535)" } in
let arr_field = fun n => { name = n, check = std.is_array, label = "Array" } in
let rec_field = fun n => { name = n, check = std.is_record, label = "Record" } in
let nullable_str = fun n => { name = n, check = nullable std.is_string, label = "String or null" } in

# --- Registry: (module:role) → field specs ---
let registry = {

  # ── Networking ──

  "tailscale:peer" = [
    bool_field "enableSSH",
    bool_field "exitNode",
    bool_field "enableHostAliases",
  ],

  "tailscale-traefik:server" = [
    str_field "domain",
    str_field "email",
    rec_field "services",
    bool_field "tailscaleSSH",
    bool_field "tailscaleExitNode",
    bool_field "traefikDashboard",
    bool_field "securityHeaders",
    bool_field "dnsPropagationCheck",
  ],

  "cloudflare-tunnel:default" = [
    str_field "tunnelName",
    rec_field "ingress",
  ],

  "iroh-ssh:peer" = [
    port_field "sshPort",
  ],

  # ── Monitoring ──

  "prometheus:server" = [
    bool_field "enableAutoDiscovery",
    str_field "discoveryMethod",
    port_field "port",
    str_field "retentionTime",
    # globalConfig, additionalScrapeConfigs, rules — NixOS pass-through
  ],

  "prometheus:exporter" = [
    str_field "exporterType",
    port_field "port",
    # enabledCollectors — optional, Array when present
    arr_field "enabledCollectors",
  ],

  "grafana:server" = [
    bool_field "enablePrometheusIntegration",
    # settings — deep NixOS pass-through (grafana.ini sections)
    rec_field "settings",
  ],

  "loki:server" = [
    bool_field "enablePromtail",
    # configuration, promtailConfig — deep NixOS pass-through
  ],

  # ── LLM & AI ──

  "llm:server" = [
    str_field "serviceType",
    port_field "port",
    str_field "host",
    bool_field "enableGPU",
    arr_field "models",
    nullable_str "model",
  ],

  "llm:client" = [
    str_field "clientType",
    arr_field "extraPackages",
  ],

  "ollama:default" = [
    str_field "host",
    arr_field "models",
  ],

  "llamacpp-rpc:worker" = [
    str_field "bindAddress",
    port_field "port",
    bool_field "enableCache",
  ],

  "llamacpp-rpc:server" = [
    str_field "host",
    port_field "port",
    rec_field "model",
    arr_field "rpcWorkers",
    num_field "gpuLayers",
    bool_field "flashAttention",
    num_field "contextSize",
  ],

  "llm-agents:default" = [
    arr_field "packages",
  ],

  # ── Web Services ──

  "homepage-dashboard:server" = [
    port_field "listenPort",
    str_field "allowedHosts",
    # inner settings, widgets — NixOS pass-through
    rec_field "settings",
    arr_field "widgets",
  ],

  "static-server:server" = [
    port_field "port",
    str_field "directory",
    bool_field "createTestPage",
    str_field "testPageTitle",
    str_field "serviceSuffix",
    bool_field "isPublic",
    str_field "domain",
    str_field "subdomain",
    str_field "testPageContent",
  ],

  # vaultwarden:server — instances have no settings, skip

  "harmonia:server" = [
    port_field "port",
    num_field "priority",
  ],

  "buildbot:master" = [
    str_field "domain",
    bool_field "useHTTPS",
    arr_field "buildSystems",
    arr_field "admins",
    num_field "evalWorkerCount",
    num_field "evalMaxMemorySize",
    str_field "outputsPath",
    str_field "ntfyUrl",
    str_field "workerName",
    num_field "workerCores",
    rec_field "github",
    rec_field "effectsSecrets",
  ],

  "buildbot:worker" = [
    num_field "workers",
  ],

  "calibre-server:server" = [
    arr_field "libraries",
    str_field "host",
    port_field "port",
    str_field "user",
    str_field "group",
  ],

  # ── Infrastructure ──

  "nix-gc:default" = [
    num_field "retentionDays",
    str_field "schedule",
    bool_field "optimizeStore",
    bool_field "autoOptimise",
  ],

  "syncthing:peer" = [
    str_field "user",
    str_field "dataDir",
    bool_field "openFirewall",
  ],

  "home-manager-profiles:default" = [
    str_field "username",
    arr_field "profiles",
  ],

  "borgbackup:server" = [
    str_field "directory",
  ],

  # borgbackup:client — no settings
}
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
      |> std.array.flat_map (fun { name, check, label } =>
        if std.record.has_field name settings then
          let val = settings."%{name}" in
          if check val then
            []
          else
            ["%{path}.settings.%{name}: expected %{label}, got %{type_name val}"]
        else
          []
      )
    else
      [],
}
