let Positive =
  std.contract.from_predicate (fun value =>
    std.is_number value && value > 0
  )
in
let NonEmpty =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.length value > 0
  )
in
let AbsolutePath =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.is_match "^/[^\\x00]+$" value
  )
in
let Settings = {
  host_uid | Positive,
  socket_path | AbsolutePath,
  replay_database_path | AbsolutePath,
}
in
let Profile = {
  schema | NonEmpty,
  mode | NonEmpty,
  radicle_runtime_revision | NonEmpty,
  radicle_broker_revision | NonEmpty,
  radicle_license | NonEmpty,
  lattice_source | NonEmpty,
  lattice_revision | NonEmpty,
  lattice_license | NonEmpty,
  capabilities | Dyn,
  socket_path | AbsolutePath,
  replay_database_path | AbsolutePath,
  maximum_replay_records | Positive,
  maximum_polls | Positive,
  allowed_user_ids | Array Positive,
  transport_limits | Dyn,
  adapter_limits | Dyn,
  workflow | Dyn,
  non_claims | Array NonEmpty,
}
in
let frame_bytes = 33554432 in
let log_bytes = 16777216 in
let connection_count = 64 in
let deadline_milliseconds = 30000 in
let replay_records = 4096 in
let poll_count = 64 in
let maximum_nodes = 256 in
let maximum_edges = 1024 in
let maximum_log_references = 256 in
let maximum_log_read_bytes = 1048576 in
let maximum_total_log_bytes = 16777216 in
let maximum_request_bytes = 1048576 in
let maximum_response_bytes = 16777216 in
let maximum_in_flight = 64 in
let operation_identity_value = "1111111111111111111111111111111111111111111111111111111111111111" in
fun settings =>
  let checked | Settings = settings in
  ({
    schema = "kiln.radicle-workflow-shell.v1",
    mode = "production",
    radicle_runtime_revision = "radicle-0.24.0",
    radicle_broker_revision = "a688afde1f730ef60402a809d9cdadc55e8dd749",
    radicle_license = "MIT OR Apache-2.0",
    lattice_source = "ssh://git@github.com/OnixResearch/lattice.git",
    lattice_revision = "70496e67c7fd4a8b05914161a8e09de2759bebc8",
    lattice_license = "MIT",
    capabilities = {
      source = false,
      trigger = true,
      status = false,
      collaboration = false,
    },
    socket_path = checked.socket_path,
    replay_database_path = checked.replay_database_path,
    maximum_replay_records = replay_records,
    maximum_polls = poll_count,
    allowed_user_ids = [checked.host_uid],
    transport_limits = {
      maximum_frame_bytes = frame_bytes,
      maximum_log_bytes = log_bytes,
      maximum_connections = connection_count,
      read_deadline_milliseconds = deadline_milliseconds,
      write_deadline_milliseconds = deadline_milliseconds,
    },
    adapter_limits = {
      max_request_bytes = maximum_request_bytes,
      max_response_bytes = maximum_response_bytes,
      max_in_flight = maximum_in_flight,
    },
    workflow = {
      policy_id = "radicle-ci-workflow-v1",
      provider_profile_id = "lattice-v1",
      platform = "linux-x86_64",
      nodes = [
        {
          id = "build",
          kind = "build",
          effect_class = "build",
          adapter_kind = "local",
          operation_identity = operation_identity_value,
        }
      ],
      edges = [],
      controls = { cancel = true, pause = false, resume = false },
      bounds = {
        max_nodes = maximum_nodes,
        max_edges = maximum_edges,
        max_log_references = maximum_log_references,
        max_log_read_bytes = maximum_log_read_bytes,
        max_total_log_bytes = maximum_total_log_bytes,
      },
    },
    non_claims = [
      "broker admission does not prove event completeness",
      "source context does not prove source trust or revision availability",
      "workflow acceptance does not prove an external effect started",
      "workflow observation does not replace canonical Kiln CI state",
      "local replay admission does not prove distributed exactly-once delivery",
      "adapter checks do not establish release readiness",
    ],
  }
  ) | Profile
