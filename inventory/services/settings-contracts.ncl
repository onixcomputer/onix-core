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
# Each returns { name, check, label, required } describing one expected field.
# `check` is a predicate: value → bool.
# `label` is the human-readable type shown in error messages.
# `required` (default false) — when true, the field must be present.
let mk_field = fun req n chk lbl => { name = n, check = chk, label = lbl, required = req } in
let bool_field = fun n => mk_field false n std.is_bool "Bool" in
let str_field = fun n => mk_field false n std.is_string "String" in
let num_field = fun n => mk_field false n std.is_number "Number" in
let port_field = fun n => mk_field false n is_port "Port (1-65535)" in
let arr_field = fun n => mk_field false n std.is_array "Array" in
let rec_field = fun n => mk_field false n std.is_record "Record" in
let nullable_str = fun n => mk_field false n (nullable std.is_string) "String or null" in
let nullable_rec = fun n => mk_field false n (nullable std.is_record) "Record or null" in

# Required variants — field must be present in settings.
let req_str = fun n => mk_field true n std.is_string "String" in
let req_port = fun n => mk_field true n is_port "Port (1-65535)" in
let req_num = fun n => mk_field true n std.is_number "Number" in
let req_rec = fun n => mk_field true n std.is_record "Record" in

# --- Registry: (module:role) → field specs ---
let registry = {

  # ── Networking ──

  "tailscale:peer" = [
    bool_field "enableSSH",
    bool_field "exitNode",
    bool_field "enableHostAliases",
  ],

  "tailscale-traefik:server" = [
    req_str "domain",
    req_str "email",
    rec_field "services",
    bool_field "tailscaleSSH",
    bool_field "tailscaleExitNode",
    bool_field "traefikDashboard",
    bool_field "securityHeaders",
    bool_field "dnsPropagationCheck",
    bool_field "sslRedirect",
    num_field "ddclientInterval",
    arr_field "dnsResolvers",
    num_field "dnsPropagationDelay",
    arr_field "additionalSubdomains",
    port_field "tailscalePort",
    rec_field "extraTraefikConfig",
    rec_field "extraDynamicConfig",
    nullable_str "tailscaleAuthKeyFile",
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
    rec_field "globalConfig",
    arr_field "additionalScrapeConfigs",
    arr_field "rules",
  ],

  "prometheus:exporter" = [
    req_str "exporterType",
    port_field "port",
    # enabledCollectors — optional, Array when present
    arr_field "enabledCollectors",
  ],

  "grafana:server" = [
    bool_field "enablePrometheusIntegration",
    rec_field "settings",
    nullable_str "prometheusUrl",
    arr_field "additionalDatasources",
    arr_field "dashboards",
    arr_field "notifiers",
  ],

  "loki:server" = [
    bool_field "enablePromtail",
    rec_field "configuration",
    rec_field "promtailConfig",
    str_field "lokiUrl",
    arr_field "additionalScrapeConfigs",
  ],

  # ── LLM & AI ──

  "llm:server" = [
    str_field "serviceType",
    port_field "port",
    str_field "host",
    bool_field "enableGPU",
    arr_field "models",
    nullable_str "model",
    nullable_str "containerImage",
    rec_field "extraEnv",
    bool_field "autoStart",
  ],

  "llm:client" = [
    str_field "clientType",
    arr_field "extraPackages",
    nullable_str "defaultServer",
  ],

  "ollama:default" = [
    str_field "host",
    port_field "port",
    arr_field "models",
    bool_field "enableGPU",
    str_field "acceleration",
  ],

  "llamacpp-rpc:worker" = [
    str_field "bindAddress",
    port_field "port",
    bool_field "enableCache",
  ],

  "llamacpp-rpc:server" = [
    str_field "host",
    port_field "port",
    nullable_rec "model",
    arr_field "rpcWorkers",
    num_field "gpuLayers",
    bool_field "flashAttention",
    num_field "contextSize",
    bool_field "noMmap",
    arr_field "extraArgs",
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
    req_str "domain",
    bool_field "useHTTPS",
    arr_field "buildSystems",
    arr_field "admins",
    num_field "evalWorkerCount",
    num_field "evalMaxMemorySize",
    str_field "outputsPath",
    str_field "ntfyUrl",
    req_str "workerName",
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

  # ── Virtualization ──

  "cloud-hypervisor-vm:host" = [
    req_str "guestMachine",
    num_field "cpus",
    num_field "memory",
    req_str "diskPath",
    str_field "diskSize",
    req_str "tapInterface",
    req_str "macAddress",
    req_str "guestIp",
  ],

  # ── Agent Infrastructure ──

  "clankers:router" = [
    str_field "listenAddr",
    port_field "listenPort",
    bool_field "useOAuth",
    arr_field "proxyKeys",
    arr_field "extraArgs",
  ],

  "clankers:daemon" = [
    str_field "model",
    bool_field "allowAll",
    num_field "heartbeat",
    nullable_str "apiBase",
    arr_field "extraArgs",
  ],
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
