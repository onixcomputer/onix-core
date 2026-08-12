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
  placeholderPattern = ".*(REPLACE|replace|placeholder|example).*";
  secretNamePattern = "^DGX_[A-Z0-9_]+$";
  machineNamePattern = "^[a-zA-Z_][a-zA-Z0-9_-]*$";
  targetHostPattern = "^root@[a-zA-Z0-9._-]+$";
  sshFingerprintPattern = "^SHA256:[a-zA-Z0-9+/=]+$";
  backendUnitPattern = "^[a-zA-Z0-9@_.:-]+[.]service$";

  hasText = value: builtins.isString value && value != "";
  isPlaceholder = value: !hasText value || builtins.match placeholderPattern value != null;
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
      hasBackendUnit = hasText backendUnit;
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
      hasBackendUnit && builtins.match backendUnitPattern backendUnit == null
    ) "${name}: mesh backend unit must be a systemd service name"
    ++ errorWhen (
      hasBackendUnit == backendExternallyManaged
    ) "${name}: mesh backend must name one unit or declare external ownership";
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
