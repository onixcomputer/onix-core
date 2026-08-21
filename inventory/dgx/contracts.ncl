# Typed source contract for Devenv-owned DGX machines.
let required_system = "aarch64-linux" in
let local_backend_unit = "llamacpp-server-dgx-local.service" in
let placeholder_pattern = ".*(REPLACE|replace|placeholder|example).*" in

let Name =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[a-zA-Z_][a-zA-Z0-9_-]*$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "invalid Devenv machine name: \"%{value}\"" },
    _ => 'Error { message = "machine name must be a string" },
  }
  )
in

let RequiredSystem =
  std.contract.from_validator (match {
    value if value == required_system => 'Ok,
    value if std.is_string value =>
      'Error { message = "DGX system must be %{required_system}, got \"%{value}\"" },
    _ => 'Error { message = "system must be a string" },
  }
  )
in

let TargetHost =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^root@[a-zA-Z0-9._-]+$" value
      && !std.string.is_match placeholder_pattern value => 'Ok,
    value if std.is_string value =>
      'Error { message = "targetHost must be root@host, got \"%{value}\"" },
    _ => 'Error { message = "targetHost must be a string" },
  }
  )
in

let StableDisk =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^/dev/disk/by-id/[a-zA-Z0-9._:+-]+$" value
      && value != "/dev/disk/by-id/."
      && value != "/dev/disk/by-id/.."
      && !std.string.is_match placeholder_pattern value => 'Ok,
    value if std.is_string value =>
      'Error { message = "diskById must be a real /dev/disk/by-id path, got \"%{value}\"" },
    _ => 'Error { message = "diskById must be a string" },
  }
  )
in

let RelativeFile =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[a-zA-Z0-9._/-]+$" value
      && !std.string.is_match placeholder_pattern value => 'Ok,
    value if std.is_string value =>
      'Error { message = "file path must be a safe non-placeholder relative path, got \"%{value}\"" },
    _ => 'Error { message = "file path must be a string" },
  }
  )
in

let HostKeyFingerprint =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^SHA256:[a-zA-Z0-9+/=]+$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "sshHostFingerprint must use SHA256:... form, got \"%{value}\"" },
    _ => 'Error { message = "sshHostFingerprint must be a string" },
  }
  )
in

let AccessPolicy =
  std.contract.from_validator (match {
    "framework-only" => 'Ok,
    value if std.is_string value =>
      'Error { message = "accessPolicy must be framework-only, got \"%{value}\"" },
    _ => 'Error { message = "accessPolicy must be a string" },
  }
  )
in

let SecretName =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^DGX_[A-Z0-9_]+$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "runtime secret name must use DGX_* identifier form, got \"%{value}\"" },
    _ => 'Error { message = "runtime secret name must be a string" },
  }
  )
in

let BackendUnit =
  std.contract.from_validator (match {
    value if value == local_backend_unit => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "local backend unit must be %{local_backend_unit}, got \"%{value}\"",
      },
    _ => 'Error { message = "backend unit must be a string" },
  }
  )
in

let ModelAlias =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[a-zA-Z0-9._/+:-]+$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "model alias contains unsupported characters: \"%{value}\"" },
    _ => 'Error { message = "model alias must be a string" },
  }
  )
in

let ModelRepository =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "model repository must use owner/name form, got \"%{value}\"" },
    _ => 'Error { message = "model repository must be a string" },
  }
  )
in

let ModelRevision =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[0-9a-f]{40}$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "model revision must be a 40-character commit, got \"%{value}\"" },
    _ => 'Error { message = "model revision must be a string" },
  }
  )
in

let ModelFile =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[a-zA-Z0-9._+:-]+(/[a-zA-Z0-9._+:-]+)*[.]gguf$" value
      && !std.string.is_match "(^|/)\\.{1,2}(/|$)" value
      && !std.string.is_match placeholder_pattern value => 'Ok,
    value if std.is_string value =>
      'Error { message = "model file must be a safe GGUF path, got \"%{value}\"" },
    _ => 'Error { message = "model file must be a string" },
  }
  )
in

let ModelSha256 =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[0-9a-f]{64}$" value => 'Ok,
    value if std.is_string value =>
      'Error { message = "model sha256 must be 64 lowercase hexadecimal characters" },
    _ => 'Error { message = "model sha256 must be a string" },
  }
  )
in

let PositiveNumber =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let NonNegativeNumber =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

let LocalModel = {
  alias | ModelAlias,
  repository | ModelRepository,
  revision | ModelRevision,
  file | ModelFile,
  sha256 | ModelSha256,
  contextSize | PositiveNumber,
  gpuLayers | NonNegativeNumber,
  flashAttention | Bool,
  noMmap | Bool,
  enableMetrics | Bool,
  extraArgs | Array String,
}
in

let BackendOwnership = {
  unit | BackendUnit | optional,
  externallyManaged | Bool,
  modelAlias | ModelAlias,
  localModel | LocalModel | optional,
}
in

let RuntimeSecrets = {
  tailscaleAuthKey | SecretName,
  meshJoinToken | SecretName,
  irohPrivateKey | SecretName,
  irohPublicKey | SecretName,
}
in

let DgxMachineContract = {
  name | Name,
  system | RequiredSystem,
  targetHost | TargetHost,
  diskById | StableDisk,
  diskoModule | RelativeFile,
  facterReport | RelativeFile,
  knownHostsFile | RelativeFile,
  sshHostFingerprint | HostKeyFingerprint,
  accessPolicy | AccessPolicy,
  runtimeSecrets | RuntimeSecrets,
  meshBackend | BackendOwnership,
}
in

let NameAndPathMatch =
  std.contract.from_validator (fun machines =>
    std.record.to_array machines
    |> std.array.map (fun { field, value } =>
      let has_backend_unit =
        std.record.has_field "unit" value.meshBackend
        && value.meshBackend.unit != ""
      in
      if value.name != field then
        'Error { message = "%{field}: name \"%{value.name}\" does not match attr key" }
      else if value.diskoModule != ".machines/%{field}/disko.nix" then
        'Error { message = "%{field}: diskoModule must be .machines/%{field}/disko.nix" }
      else if value.facterReport != ".machines/%{field}/facter.json" then
        'Error { message = "%{field}: facterReport must be .machines/%{field}/facter.json" }
      else if value.knownHostsFile != ".machines/%{field}/known_hosts" then
        'Error { message = "%{field}: knownHostsFile must be .machines/%{field}/known_hosts" }
      else if value.runtimeSecrets.tailscaleAuthKey == value.runtimeSecrets.meshJoinToken
      || value.runtimeSecrets.tailscaleAuthKey == value.runtimeSecrets.irohPrivateKey
      || value.runtimeSecrets.tailscaleAuthKey == value.runtimeSecrets.irohPublicKey
      || value.runtimeSecrets.meshJoinToken == value.runtimeSecrets.irohPrivateKey
      || value.runtimeSecrets.meshJoinToken == value.runtimeSecrets.irohPublicKey
      || value.runtimeSecrets.irohPrivateKey == value.runtimeSecrets.irohPublicKey then
        'Error { message = "%{field}: runtime secret names must be distinct" }
      else if has_backend_unit == value.meshBackend.externallyManaged then
        'Error { message = "%{field}: meshBackend must name one unit or declare external ownership" }
      else if value.meshBackend.externallyManaged
      && std.record.has_field "localModel" value.meshBackend then
        'Error { message = "%{field}: an externally managed backend cannot declare localModel" }
      else if !value.meshBackend.externallyManaged
      && std.record.has_field "localModel" value.meshBackend
      && value.meshBackend.modelAlias != value.meshBackend.localModel.alias then
        'Error { message = "%{field}: local model alias must match meshBackend.modelAlias" }
      else
        'Ok
    )
    |> std.array.filter (match { 'Error _ => true, _ => false })
    |> match {
      [] => 'Ok,
      [error, ..] => error,
    }
  )
in

let DgxMachinesContract = {
  machines | { _ : DgxMachineContract } | NameAndPathMatch,
}
in

{
  DgxMachine = DgxMachineContract,
  DgxMachines = DgxMachinesContract,
}
