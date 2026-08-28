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
let Blake3Identity =
  std.contract.from_predicate (fun value =>
    std.is_string value && std.string.is_match "^b3:[0-9a-f]{64}$" value
  )
in
let Settings = {
  host_uid | Positive,
  socket_path | AbsolutePath,
}
in
let RouteNode = {
  request_node_id | NonEmpty,
  operation_identity | Blake3Identity,
  workflow_node_id | Number,
}
in
let Route = {
  profile_identity | Blake3Identity,
  graph_identity | Blake3Identity,
  workflow_name | NonEmpty,
  workflow_revision | Blake3Identity,
  effect_authority | std.contract.from_predicate (fun value => value == "route_exact"),
  source_binding | std.contract.from_predicate (fun value => value == "shell_environment"),
  nodes | Array RouteNode,
}
in
let HandlerProfile = {
  schema
    | std.contract.from_predicate (fun value =>
      value == "lattice.workflow-exchange-handler-profile.v1"
    ),
  socket_path | AbsolutePath,
  transport | Dyn,
  maximum_active_executions | Positive,
  routes | Array Route,
  non_claims | Array NonEmpty,
}
in
let frame_bytes = 33554432 in
let log_bytes = 16777216 in
let connection_count = 64 in
let active_execution_count = 1 in
let deadline_milliseconds = 30000 in
let profile_identity_value = "b3:67f30a749eaa91b56a5a0e42873c9b13968ff92ae87f577c6f36041f4a722cb5" in
let graph_identity_value = "b3:a5af82f6dc0f5b094624022825ba048775cc4892bfdd12473bb57945e8745426" in
let workflow_revision_value = "b3:1377fce07f3426f87ab7c61d6a716d3f1fc95be71f91ab87699e13f56dbd35b3" in
let operation_identity_value = "b3:1111111111111111111111111111111111111111111111111111111111111111" in
fun settings =>
  let checked | Settings = settings in
  ({
    schema = "lattice.workflow-exchange-handler-profile.v1",
    socket_path = checked.socket_path,
    transport = {
      schema = "lattice.workflow-transport-profile.v1",
      limits = {
        maximum_frame_bytes = frame_bytes,
        maximum_log_bytes = log_bytes,
        maximum_connections = connection_count,
        read_deadline_milliseconds = deadline_milliseconds,
        write_deadline_milliseconds = deadline_milliseconds,
      },
      peers = { allowed_user_ids = [checked.host_uid] },
      non_claims = [
        "transport admission does not prove workflow correctness",
        "transport peer identity does not prove peer intent",
        "transport acceptance does not prove an operation executed",
        "transport response does not prove an external effect succeeded",
        "transport checks do not establish production deployment",
      ],
    },
    maximum_active_executions = active_execution_count,
    routes = [
      {
        profile_identity = profile_identity_value,
        graph_identity = graph_identity_value,
        workflow_name = "kiln-aspen-canary",
        workflow_revision = workflow_revision_value,
        effect_authority = "route_exact",
        source_binding = "shell_environment",
        nodes = [
          {
            request_node_id = "build",
            operation_identity = operation_identity_value,
            workflow_node_id = 0,
          }
        ],
      }
    ],
    non_claims = [
      "handler admission does not prove workflow correctness",
      "route authority does not prove host confinement",
      "execution observation does not prove an external effect succeeded",
      "peer identity does not prove peer intent",
      "handler checks do not establish release readiness",
    ],
  }
  ) | HandlerProfile
