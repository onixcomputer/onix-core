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
  data_dir | AbsolutePath,
  shell | AbsolutePath,
}
in
let Config = {
  data_dir | AbsolutePath,
  default_timeout_secs | std.contract.from_predicate (fun value => value > 0),
  shell | NonEmpty,
  max_parallelism | std.contract.from_predicate (fun value => value > 0),
  resource_lanes | Dyn,
  process_limits
    | {
      stdin_max_bytes | std.contract.from_predicate (fun value => value > 0),
      stdout_max_bytes | std.contract.from_predicate (fun value => value > 0),
      stderr_max_bytes | std.contract.from_predicate (fun value => value > 0),
      command_agent_timeout_secs | std.contract.from_predicate (fun value => value > 0),
      poll_interval_millis | std.contract.from_predicate (fun value => value > 0),
      teardown_grace_millis | std.contract.from_predicate (fun value => value > 0),
    },
}
in
let stdin_maximum_bytes = 4096 in
let output_maximum_bytes = 65536 in
let command_timeout_seconds = 30 in
let poll_interval_milliseconds = 10 in
let teardown_grace_milliseconds = 1000 in
fun settings =>
  let checked | Settings = settings in
  ({
    data_dir = checked.data_dir,
    default_timeout_secs = 30,
    shell = checked.shell,
    max_parallelism = 1,
    resource_lanes = {},
    process_limits = {
      stdin_max_bytes = stdin_maximum_bytes,
      stdout_max_bytes = output_maximum_bytes,
      stderr_max_bytes = output_maximum_bytes,
      command_agent_timeout_secs = command_timeout_seconds,
      poll_interval_millis = poll_interval_milliseconds,
      teardown_grace_millis = teardown_grace_milliseconds,
    },
  }
  ) | Config
