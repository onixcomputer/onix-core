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
  data_dir | AbsolutePath,
  shell | AbsolutePath,
  command_timeout_seconds | Positive,
}
in
let Config = {
  data_dir | AbsolutePath,
  default_timeout_secs | Positive,
  shell | NonEmpty,
  max_parallelism | Positive,
  resource_lanes | Dyn,
  process_limits
    | {
      stdin_max_bytes | Positive,
      stdout_max_bytes | Positive,
      stderr_max_bytes | Positive,
      command_agent_timeout_secs | Positive,
      poll_interval_millis | Positive,
      teardown_grace_millis | Positive,
    },
}
in
let stdin_maximum_bytes = 4096 in
let output_maximum_bytes = 1048576 in
let maximum_parallelism = 1 in
let poll_interval_milliseconds = 10 in
let teardown_grace_milliseconds = 30000 in
fun settings =>
  let checked | Settings = settings in
  ({
    data_dir = checked.data_dir,
    default_timeout_secs = checked.command_timeout_seconds,
    shell = checked.shell,
    max_parallelism = maximum_parallelism,
    resource_lanes = {},
    process_limits = {
      stdin_max_bytes = stdin_maximum_bytes,
      stdout_max_bytes = output_maximum_bytes,
      stderr_max_bytes = output_maximum_bytes,
      command_agent_timeout_secs = checked.command_timeout_seconds,
      poll_interval_millis = poll_interval_milliseconds,
      teardown_grace_millis = teardown_grace_milliseconds,
    },
  }
  ) | Config
