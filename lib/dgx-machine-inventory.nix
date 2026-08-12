{ lib }:
let
  requiredSystem = "aarch64-linux";
  requiredSecretFields = [
    "tailscaleAuthKey"
    "meshJoinToken"
    "irohPrivateKey"
    "irohPublicKey"
  ];
  requiredFileFields = [
    "diskoModule"
    "facterReport"
    "knownHostsFile"
  ];
  requiredLocalModelFields = [
    "alias"
    "repository"
    "revision"
    "file"
    "sha256"
    "contextSize"
    "gpuLayers"
    "flashAttention"
    "noMmap"
    "enableMetrics"
    "extraArgs"
  ];
  rwkvProfile = import ../modules/dgx-machine/rwkv7-profile.nix;
  localBackendUnit = "llamacpp-server-dgx-local.service";
  placeholderPattern = ".*(REPLACE|replace|placeholder|example).*";
  secretNamePattern = "^DGX_[A-Z0-9_]+$";
  machineNamePattern = "^[a-zA-Z_][a-zA-Z0-9_-]*$";
  targetHostPattern = "^root@[a-zA-Z0-9._-]+$";
  sshFingerprintPattern = "^SHA256:[a-zA-Z0-9+/=]+$";
  modelAliasPattern = "^[a-zA-Z0-9._/+:-]+$";
  modelRepositoryPattern = "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$";
  modelRevisionPattern = "^[0-9a-f]{40}$";
  modelFilePattern = "^[a-zA-Z0-9._+:-]+(/[a-zA-Z0-9._+:-]+)*[.]gguf$";
  modelSha256Pattern = "^[0-9a-f]{64}$";

  hasText = value: builtins.isString value && value != "";
  matchesPattern = pattern: value: builtins.isString value && builtins.match pattern value != null;
  isPlaceholder = value: !hasText value || builtins.match placeholderPattern value != null;
  isSafeRelativeModelPath =
    value:
    hasText value
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" value
    );
  errorWhen = condition: message: lib.optional condition message;

  validateMachine =
    {
      name,
      machine,
      pathExists,
      requireFiles,
    }:
    let
      backendValue = machine.meshBackend or { };
      backend = if builtins.isAttrs backendValue then backendValue else { };
      backendUnit = backend.unit or null;
      backendExternallyManaged = backend.externallyManaged or false;
      backendModelAlias = backend.modelAlias or null;
      hasBackendUnit = hasText backendUnit;
      hasLocalModel = builtins.hasAttr "localModel" backend;
      localModelValue = backend.localModel or { };
      localModel = if builtins.isAttrs localModelValue then localModelValue else { };
      missingLocalModelFields = lib.filter (
        field: hasLocalModel && !(builtins.hasAttr field localModel)
      ) requiredLocalModelFields;
      localModelExtraArgs = localModel.extraArgs or null;
      localModelErrors =
        errorWhen (!builtins.isAttrs localModelValue) "${name}: meshBackend.localModel must be a record"
        ++ map (field: "${name}: missing local model field ${field}") missingLocalModelFields
        ++ errorWhen (
          hasLocalModel && !(matchesPattern modelAliasPattern (localModel.alias or null))
        ) "${name}: invalid local model alias"
        ++ errorWhen (
          hasLocalModel && !(matchesPattern modelRepositoryPattern (localModel.repository or null))
        ) "${name}: invalid local model repository"
        ++ errorWhen (
          hasLocalModel && !(matchesPattern modelRevisionPattern (localModel.revision or null))
        ) "${name}: invalid local model revision"
        ++ errorWhen (
          hasLocalModel
          && (
            !(matchesPattern modelFilePattern (localModel.file or null))
            || !(isSafeRelativeModelPath (localModel.file or null))
            || isPlaceholder (localModel.file or "")
          )
        ) "${name}: invalid local model GGUF file"
        ++ errorWhen (
          hasLocalModel && !(matchesPattern modelSha256Pattern (localModel.sha256 or null))
        ) "${name}: invalid local model sha256"
        ++ errorWhen (
          hasLocalModel && (!(builtins.isInt (localModel.contextSize or null)) || localModel.contextSize <= 0)
        ) "${name}: local model contextSize must be a positive integer"
        ++ errorWhen (
          hasLocalModel && (!(builtins.isInt (localModel.gpuLayers or null)) || localModel.gpuLayers < 0)
        ) "${name}: local model gpuLayers must be a non-negative integer"
        ++ errorWhen (
          hasLocalModel && !builtins.isBool (localModel.flashAttention or null)
        ) "${name}: local model flashAttention must be a boolean"
        ++ errorWhen (
          hasLocalModel && !builtins.isBool (localModel.noMmap or null)
        ) "${name}: local model noMmap must be a boolean"
        ++ errorWhen (
          hasLocalModel && !builtins.isBool (localModel.enableMetrics or null)
        ) "${name}: local model enableMetrics must be a boolean"
        ++ errorWhen (
          hasLocalModel
          && (!builtins.isList localModelExtraArgs || !(lib.all builtins.isString localModelExtraArgs))
        ) "${name}: local model extraArgs must be a string list";
      secretsValue = machine.runtimeSecrets or { };
      secrets = if builtins.isAttrs secretsValue then secretsValue else { };
      missingSecretFields = lib.filter (field: !(builtins.hasAttr field secrets)) requiredSecretFields;
      invalidSecretFields = lib.filter (
        field:
        builtins.hasAttr field secrets
        && (!hasText secrets.${field} || builtins.match secretNamePattern secrets.${field} == null)
      ) requiredSecretFields;
      secretNames = map (field: secrets.${field}) (
        lib.filter (field: builtins.hasAttr field secrets && hasText secrets.${field}) requiredSecretFields
      );
      hasDuplicateSecretNames = builtins.length (lib.unique secretNames) != builtins.length secretNames;
      diskById = machine.diskById or "";
      diskBaseName = if hasText diskById then builtins.baseNameOf diskById else "";
      missingFileFields = lib.filter (field: !(builtins.hasAttr field machine)) requiredFileFields;
      invalidFileFields = lib.filter (
        field: builtins.hasAttr field machine && !hasText machine.${field}
      ) requiredFileFields;
      absentFiles = lib.filter (
        field:
        builtins.hasAttr field machine
        && hasText machine.${field}
        && requireFiles
        && !(pathExists machine.${field})
      ) requiredFileFields;
      targetHost = machine.targetHost or null;
      sshHostFingerprint = machine.sshHostFingerprint or null;
    in
    errorWhen (builtins.match machineNamePattern name == null) "${name}: invalid Devenv machine name"
    ++ errorWhen ((machine.name or null) != name) "${name}: name does not match its inventory key"
    ++ errorWhen (
      (machine.system or null) != requiredSystem
    ) "${name}: system must be ${requiredSystem}"
    ++ errorWhen (
      (machine.accessPolicy or null) != "framework-only"
    ) "${name}: accessPolicy must be framework-only"
    ++ errorWhen (
      isPlaceholder targetHost || builtins.match targetHostPattern targetHost == null
    ) "${name}: targetHost must be a real root@host target"
    ++ errorWhen (
      !hasText diskById
      || !(lib.hasPrefix "/dev/disk/by-id/" diskById)
      || isPlaceholder diskById
      || builtins.elem diskBaseName [
        "."
        ".."
      ]
    ) "${name}: diskById must be a real /dev/disk/by-id path"
    ++ errorWhen (
      isPlaceholder sshHostFingerprint || builtins.match sshFingerprintPattern sshHostFingerprint == null
    ) "${name}: SSH host fingerprint must use SHA256 form"
    ++ errorWhen (!builtins.isAttrs secretsValue) "${name}: runtimeSecrets must be a record"
    ++ errorWhen (!builtins.isAttrs backendValue) "${name}: meshBackend must be a record"
    ++ errorWhen (
      !builtins.isBool backendExternallyManaged
    ) "${name}: meshBackend.externallyManaged must be a boolean"
    ++ map (field: "${name}: missing ${field}") missingFileFields
    ++ map (field: "${name}: invalid ${field}") invalidFileFields
    ++ map (field: "${name}: ${field} does not exist") absentFiles
    ++ map (field: "${name}: missing runtime secret name ${field}") missingSecretFields
    ++ map (field: "${name}: invalid runtime secret name ${field}") invalidSecretFields
    ++ errorWhen hasDuplicateSecretNames "${name}: runtime secret names must be distinct"
    ++ errorWhen (
      !(matchesPattern modelAliasPattern backendModelAlias)
    ) "${name}: mesh backend modelAlias is invalid"
    ++ errorWhen (
      hasBackendUnit && backendUnit != localBackendUnit
    ) "${name}: local mesh backend unit must be ${localBackendUnit}"
    ++ errorWhen (
      hasBackendUnit == backendExternallyManaged
    ) "${name}: mesh backend must name one unit or declare external ownership"
    ++ errorWhen (
      backendExternallyManaged && hasLocalModel
    ) "${name}: an externally managed backend cannot declare a local model"
    ++ errorWhen (
      !backendExternallyManaged && hasLocalModel && backendModelAlias != (localModel.alias or null)
    ) "${name}: local model alias must match mesh backend modelAlias"
    ++ errorWhen (
      !backendExternallyManaged && !hasLocalModel && backendModelAlias != rwkvProfile.alias
    ) "${name}: the default local model alias must be ${rwkvProfile.alias}"
    ++ localModelErrors;
in
{
  inherit requiredSystem;

  validateInventory =
    {
      inventory,
      clanMachineNames ? [ ],
      pathExists ? _path: true,
      requireFiles ? false,
    }:
    let
      machines = inventory.machines or { };
      names = builtins.attrNames machines;
      duplicateOwners = lib.intersectLists names clanMachineNames;
      machineErrors = lib.concatLists (
        lib.mapAttrsToList (
          name: machine:
          if builtins.isAttrs machine then
            validateMachine {
              inherit
                name
                machine
                pathExists
                requireFiles
                ;
            }
          else
            [ "${name}: machine record must be an attribute set" ]
        ) machines
      );
      ownershipErrors = map (name: "${name}: machine is owned by both Devenv and Clan") duplicateOwners;
      errors = ownershipErrors ++ machineErrors;
    in
    {
      inherit
        duplicateOwners
        errors
        machines
        names
        ;
      valid = errors == [ ];
    };
}
