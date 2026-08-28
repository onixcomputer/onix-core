let default_host_uid = 972 in
let default_lattice_uid = 973 in
let default_maximum_requests = 64 in
let default_request_timeout_milliseconds = 30000 in
let default_provider_timeout_milliseconds = 7200000 in
let default_output_max_bytes = 8388608 in
let default_report_max_bytes = 16777216 in
let default_wrapper_max_bytes = 262144 in
let default_provider_poll_milliseconds = 100 in
let default_teardown_timeout_milliseconds = 30000 in
let default_stage_collision_attempts = 8 in
{
  default = {
    enable = {
      type = "bool",
      default = false,
      description = "Enable the private production Kiln-on-Aspen Radicle CI cohort",
    },
    runtimeName = {
      type = "string",
      default = "kiln-aspen-ci",
      description = "Unique production service, user, socket, and state name stem",
    },
    routeMode = {
      type = "string",
      default = "shadow",
      description = "Explicit broker route: shadow, aspen, or legacy",
    },
    hostStateDir = {
      type = "string",
      default = "/var/lib/kiln-aspen-radicle-ci/host",
      description = "Private durable Aspen host state root",
    },
    latticeStateDir = {
      type = "string",
      default = "/var/lib/kiln-aspen-radicle-ci/lattice",
      description = "Private Lattice workflow state root",
    },
    sourcePath = {
      type = "string",
      default = "/var/lib/radicle/storage/z3xXXCQXCTquvAawh41YYs8yC8xmk",
      description = "Exact host-side Seaglass bare repository",
    },
    sourceView = {
      type = "string",
      default = "/var/lib/kiln-aspen-radicle-ci/source/seaglass.git",
      description = "Read-only repository path visible inside the Lattice service",
    },
    reportPath = {
      type = "string",
      default = "/var/lib/radicle-ci/reports/aspen",
      description = "Host-side report directory served by the existing report service",
    },
    reportView = {
      type = "string",
      default = "/var/lib/kiln-aspen-radicle-ci/report-view",
      description = "Writable report path visible inside the Lattice service",
    },
    repository = {
      type = "string",
      default = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk",
      description = "Only admitted private Radicle repository ID",
    },
    reportNamespace = {
      type = "string",
      default = "seaglass",
      description = "Bounded provider report namespace",
    },
    reportBaseUrl = {
      type = "string",
      default = "https://ci.onix.computer/reports/aspen",
      description = "Published URL prefix for the production report path",
    },
    hostUid = {
      type = "number",
      default = default_host_uid,
      description = "Stable Unix identity for the durable Aspen host",
    },
    latticeUid = {
      type = "number",
      default = default_lattice_uid,
      description = "Stable Unix identity for Lattice and the bounded provider",
    },
    maximumRequests = {
      type = "number",
      default = default_maximum_requests,
      description = "Finite requests served before the durable host restarts",
    },
    requestTimeoutMilliseconds = {
      type = "number",
      default = default_request_timeout_milliseconds,
      description = "Per-connection Aspen and Lattice transport deadline",
    },
    providerTimeoutMilliseconds = {
      type = "number",
      default = default_provider_timeout_milliseconds,
      description = "Bounded Nix provider execution deadline",
    },
    providerStdoutMaxBytes = {
      type = "number",
      default = default_output_max_bytes,
      description = "Maximum retained Nix provider stdout bytes",
    },
    providerStderrMaxBytes = {
      type = "number",
      default = default_output_max_bytes,
      description = "Maximum retained Nix provider stderr bytes",
    },
    providerReportMaxBytes = {
      type = "number",
      default = default_report_max_bytes,
      description = "Maximum durable provider report or log bytes",
    },
    providerWrapperMaxBytes = {
      type = "number",
      default = default_wrapper_max_bytes,
      description = "Maximum admitted provider wrapper bytes",
    },
    providerPollMilliseconds = {
      type = "number",
      default = default_provider_poll_milliseconds,
      description = "Bounded provider process polling interval",
    },
    providerTeardownTimeoutMilliseconds = {
      type = "number",
      default = default_teardown_timeout_milliseconds,
      description = "Bounded process-group teardown deadline",
    },
    providerStageCollisionAttempts = {
      type = "number",
      default = default_stage_collision_attempts,
      description = "Finite durable publication staging attempts",
    },
  },
}
