# Typed contracts for remote builder targets.
# r[impl onix.remote_builder.routing.contract]
let EmptyLength = 0 in
let NonEmptyString =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > EmptyLength => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

fun machine_names =>
  let ValidMachineName =
    std.contract.from_validator (fun name =>
      if std.array.elem name machine_names then
        'Ok
      else
        'Error {
          message = "unknown machine: \"%{name}\"",
          notes = ["Valid machines: %{std.string.join ", " machine_names}"],
        }
    )
  in
  let PositiveNum =
    std.contract.from_validator (match {
      value if std.is_number value && value > 0 => 'Ok,
      _ => 'Error { message = "must be a positive number" },
    }
    )
  in
  let BuilderTargetContract = {
    name | ValidMachineName,
    allowedConsumers | Array ValidMachineName | optional,
    speedFactor | PositiveNum,
    systems | Array NonEmptyString,
    sshUser | NonEmptyString,
    sshHost | NonEmptyString | optional,
    maxJobs | PositiveNum,
    supportedFeatures | Array NonEmptyString,
  }
  in
  let BuilderTargetsContract = { targets | Array BuilderTargetContract } in
  {
    BuilderTargets = BuilderTargetsContract,
  }
