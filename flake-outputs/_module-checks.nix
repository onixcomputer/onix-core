# Verify that the module registry in services/contracts.ncl stays in
# sync with the actual module directories in modules/.
#
# Catches two kinds of drift:
#   - Module registered in contracts.ncl but no directory exists
#   - Module directory exists (and is in modules/default.nix) but not
#     registered in contracts.ncl
#
# Note: borgbackup-extras and matrix-synapse-cf are plain NixOS modules
# loaded via extraModules, not clan perInstance service definitions.
# They are intentionally absent from the registry.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  moduleLists = wasm.evalNickelFile ../inventory/services/module-lists.ncl;
  llamacppServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/llamacpp-server-validation.ncl;
  sglangDiffusionValidation = wasm.evalNickelFile ../inventory/services/fixtures/sglang-diffusion-validation.ncl;
  ttInferenceServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/tt-inference-server-validation.ncl;
  rustfsValidation = wasm.evalNickelFile ../inventory/services/fixtures/rustfs-validation.ncl;

  # Modules registered in contracts.ncl (clan perInstance services only)
  registeredModules = lib.sort lib.lessThan moduleLists.selfModules;

  # Module directories on disk that are clan perInstance services
  # (i.e., listed in modules/default.nix).
  moduleDefs = import ../modules { inherit (self) inputs; };
  diskModules = lib.sort lib.lessThan (lib.attrNames moduleDefs);

  inRegistryNoDisk = lib.subtractLists diskModules registeredModules;
  onDiskNoRegistry = lib.subtractLists registeredModules diskModules;

  # Modules missing schema.ncl files
  modulesWithoutSchema = builtins.filter (
    name: !builtins.pathExists (self + "/modules/${name}/schema.ncl")
  ) diskModules;

  llamacppPositiveErrors = llamacppServerValidation.positive;
  llamacppNegativeErrors = llamacppServerValidation.negative;
  expectedLlamacppNegativeFields = [
    "backend"
    "modelSha256"
    "metaliumDeviceId"
    "metaliumInspectorPort"
    "metaliumTrace"
    "generationThreads"
    "batchThreads"
    "flashAttention"
  ];
  missingLlamacppNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) llamacppNegativeErrors)
  ) expectedLlamacppNegativeFields;

  sglangPositiveErrors = sglangDiffusionValidation.positive;
  sglangNegativeErrors = sglangDiffusionValidation.negative;
  expectedSglangNegativeFields = [
    "port"
    "numGpus"
    "gpuPassthrough"
    "environmentFiles"
  ];
  missingSglangNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) sglangNegativeErrors)
  ) expectedSglangNegativeFields;

  ttInferenceServerPositiveErrors = ttInferenceServerValidation.positive;
  ttInferenceServerNegativeErrors = ttInferenceServerValidation.negative;
  expectedTtInferenceServerNegativeFields = [
    "image"
    "model"
    "device"
    "physicalDeviceId"
    "host"
    "port"
    "cacheUid"
    "cacheGid"
    "enableTraceCapture"
    "autoStart"
    "extraArgs"
  ];
  missingTtInferenceServerNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) ttInferenceServerNegativeErrors)
  ) expectedTtInferenceServerNegativeFields;

  rustfsPositiveErrors = rustfsValidation.positive;
  rustfsNegativeErrors = rustfsValidation.negative;
  expectedRustfsNegativeFields = [
    "dataDir"
    "bindAddress"
    "apiPort"
    "consolePort"
    "enableConsole"
    "openFirewall"
    "firewallInterface"
  ];
  missingRustfsNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) rustfsNegativeErrors)
  ) expectedRustfsNegativeFields;
in
{
  checks = {
    module-registry-sync = pkgs.runCommand "module-registry-sync" { } ''
      ${lib.optionalString (inRegistryNoDisk != [ ]) ''
        echo "Modules in contracts.ncl selfModules but missing from modules/default.nix:"
        echo "  ${lib.concatStringsSep " " inRegistryNoDisk}"
        echo ""
      ''}
      ${lib.optionalString (onDiskNoRegistry != [ ]) ''
        echo "Modules in modules/default.nix but not registered in contracts.ncl:"
        echo "  ${lib.concatStringsSep " " onDiskNoRegistry}"
        echo ""
      ''}
      ${lib.optionalString (modulesWithoutSchema != [ ]) ''
        echo "Modules missing schema.ncl (needed for settings contract validation):"
        echo "  ${lib.concatStringsSep " " modulesWithoutSchema}"
        echo ""
      ''}
      ${lib.optionalString
        (inRegistryNoDisk != [ ] || onDiskNoRegistry != [ ] || modulesWithoutSchema != [ ])
        ''
          echo "Fix: update contracts.ncl and/or add schema.ncl to each module"
          exit 1
        ''
      }
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.model_process_isolation.devices] and
    # r[verify onix.tenstorrent.model_performance.trace_replay].
    llamacpp-server-settings = pkgs.runCommand "llamacpp-server-settings" { } ''
      ${lib.optionalString (llamacppPositiveErrors != [ ]) ''
        echo "Valid llamacpp-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingLlamacppNegativeFields != [ ]) ''
        echo "Invalid llamacpp-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingLlamacppNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    sglang-diffusion-settings = pkgs.runCommand "sglang-diffusion-settings" { } ''
      ${lib.optionalString (sglangPositiveErrors != [ ]) ''
        echo "Valid sglang-diffusion settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingSglangNegativeFields != [ ]) ''
        echo "Invalid sglang-diffusion settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSglangNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.vllm.p150_llama] and
    # r[verify onix.tenstorrent.vllm.secrets].
    tt-inference-server-settings = pkgs.runCommand "tt-inference-server-settings" { } ''
      ${lib.optionalString (ttInferenceServerPositiveErrors != [ ]) ''
        echo "Valid tt-inference-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingTtInferenceServerNegativeFields != [ ]) ''
        echo "Invalid tt-inference-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingTtInferenceServerNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    rustfs-settings = pkgs.runCommand "rustfs-settings" { } ''
      ${lib.optionalString (rustfsPositiveErrors != [ ]) ''
        echo "Valid rustfs settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingRustfsNegativeFields != [ ]) ''
        echo "Invalid rustfs settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingRustfsNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';
  };
}
