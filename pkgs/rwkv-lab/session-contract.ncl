let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let AbsolutePath =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.is_match "^/" value => 'Ok,
    _ => 'Error { message = "must be an absolute path" },
  }
  )
in

let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let NonNegative =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

let Stage =
  std.contract.from_validator (match {
    "data_movement" => 'Ok,
    "operator" => 'Ok,
    "layer" => 'Ok,
    "token" => 'Ok,
    "stateful_decode" => 'Ok,
    _ => 'Error { message = "must name a supported RWKV integration stage" },
  }
  )
in

let SessionContract = {
  schema_version | Positive,
  session_id | NonEmpty,
  stage | Stage,
  target
    | {
      package_path | AbsolutePath,
      kernel_path | AbsolutePath,
      executable | AbsolutePath,
      arguments | Array String,
    },
  hardware
    | {
      architecture | NonEmpty,
      physical_device | NonNegative,
      device_path | AbsolutePath,
      owner_unit | NonEmpty,
      owner_control_path | AbsolutePath,
    },
  runtime
    | {
      run_root | AbsolutePath,
      cache_path | AbsolutePath,
      logs_path | AbsolutePath,
      inspector_address | NonEmpty,
    },
  budget
    | {
      max_processes | Positive,
      timeout_seconds | Positive,
      timeout_exit_status | Positive,
      kill_grace_seconds | Positive,
    },
  restoration
    | {
      rollback_delay_seconds | Positive,
      health_url | NonEmpty,
      expected_health_status | Positive,
    },
  evidence
    | {
      required_artifact_roles | Array NonEmpty,
      success_markers | Array NonEmpty,
    },
  claims
    | {
      success | NonEmpty,
      non_claims | Array NonEmpty,
    },
}
in

{ Session = SessionContract }
