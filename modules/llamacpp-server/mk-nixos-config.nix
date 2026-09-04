{
  config,
  inputs,
  instanceName,
  lib,
  pkgs,
  settings,
}:
let
  inherit (settings)
    host
    port
    backend
    modelRepo
    modelFile
    modelRevision
    modelSha256
    extraModelFiles
    extraModelSha256
    multimodalProjectorFile
    multimodalProjectorSha256
    huggingFaceTokenRequired
    draftModelSource
    draftModelRepo
    draftModelFile
    draftModelRevision
    modelAlias
    gpuLayers
    metaliumDeviceId
    metaliumInspectorPort
    metaliumTrace
    contextSize
    generationThreads
    batchThreads
    batchSize
    ubatchSize
    parallelSlots
    cacheTypeK
    cacheTypeV
    flashAttention
    gpuPerformanceLock
    noMmap
    enableMetrics
    autoStart
    extraArgs
    ;

  serviceName = "llamacpp-server-${instanceName}";
  pullServiceName = "${serviceName}-model-pull";
  stateDirectory = serviceName;
  stateDir = "/var/lib/${stateDirectory}";
  modelsDir = "${stateDir}/models";
  modelPath = "${modelsDir}/${modelFile}";
  modelUrl = "https://huggingface.co/${modelRepo}/resolve/${modelRevision}/${modelFile}";
  hasMultimodalProjector = multimodalProjectorFile != null;
  multimodalProjectorPath =
    if hasMultimodalProjector then "${modelsDir}/${multimodalProjectorFile}" else null;
  multimodalProjectorUrl =
    if hasMultimodalProjector then
      "https://huggingface.co/${modelRepo}/resolve/${modelRevision}/${multimodalProjectorFile}"
    else
      null;
  draftModelPath = "${modelsDir}/${draftModelFile}";
  draftModelUrl = "https://huggingface.co/${draftModelRepo}/resolve/${draftModelRevision}/${draftModelFile}";
  hasDraftModel = draftModelFile != "";
  draftFromPackage = hasDraftModel && draftModelSource == "package";
  generatorName = "${serviceName}-huggingface";
  envFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
  modelAccessProbeUrl = "https://huggingface.co/${modelRepo}/resolve/${modelRevision}/.gitattributes";

  # r[impl onix.aspen1.qwen_flash.download]
  # Pure download plan: every file the pull service must fetch, including
  # GGUF shards that live in a subdirectory of the repository.
  extraModelDownloads = lib.imap0 (index: file: {
    inherit file;
    url = "https://huggingface.co/${modelRepo}/resolve/${modelRevision}/${file}";
    sha256 =
      if index < builtins.length extraModelSha256 then lib.elemAt extraModelSha256 index else null;
  }) extraModelFiles;
  modelDownloads = [
    {
      file = modelFile;
      url = modelUrl;
      sha256 = modelSha256;
    }
  ]
  ++ extraModelDownloads
  ++ lib.optional hasMultimodalProjector {
    file = multimodalProjectorFile;
    url = multimodalProjectorUrl;
    sha256 = multimodalProjectorSha256;
  }
  ++ lib.optional (hasDraftModel && !draftFromPackage) {
    file = draftModelFile;
    url = draftModelUrl;
    sha256 = null;
  };
  modelFilePaths = [
    modelFile
  ]
  ++ extraModelFiles
  ++ lib.optional hasMultimodalProjector multimodalProjectorFile
  ++ lib.optional hasDraftModel draftModelFile;
  isSafeRelativeModelPath =
    path:
    path != ""
    && lib.all (component: component != "" && component != "." && component != "..") (
      lib.splitString "/" path
    );
  metaliumCacheDir = "${stateDir}/cache";
  metaliumLogsDir = "${stateDir}/tt-metal-logs";

  stateDirectoryMode = "0755";
  modelFileMode = "0644";
  secretFileMode = "0400";
  temporarySecretMode = "0600";
  partialSuffix = ".partial";
  pullRestartDelay = "60s";
  serverRestartDelay = "10s";
  infiniteTimeout = "infinity";
  curlRetryCount = 5;
  curlRetryDelaySeconds = 10;
  accessProbeTimeoutSeconds = 30;
  disabledNumericOption = 0;
  stockSopsPlaceholder = "Welcome to SOPS! Edit this file as you please!";
  huggingFaceTokenPrefix = "hf_";
  radeonDeviceIndex = 0;
  metaliumBackendName = "metalium";
  metaliumBackendEnabled = backend == metaliumBackendName;
  metaliumTraceEnvironmentValue = if metaliumTrace then "1" else "0";
  hostSystem = pkgs.stdenv.hostPlatform.system;
  tenstorrentPackages = inputs.tenstorrent-nix.packages.${hostSystem};
  metaliumPackage = tenstorrentPackages.llama-cpp-metalium;
  cudaGpuLayerCount = gpuLayers;
  cpuGpuLayerCount = 0;
  effectiveGpuLayers = if backend == "cpu" then cpuGpuLayerCount else cudaGpuLayerCount;
  exposedModelName = if modelAlias != null then modelAlias else modelFile;

  # CUDA 12.9's cuda_compat redistributable is unavailable for linux-x86_64
  # in this nixpkgs manifest. Build llama.cpp without the forward-compat hook.
  disabledCudaCompatRunpathHook =
    pkgs.runCommand "auto-add-cuda-compat-runpath-hook-disabled"
      {
        passthru.enableHook = false;
      }
      ''
        mkdir -p $out/nix-support
        touch $out/nix-support/setup-hook
      '';
  cudaPackagesWithoutCompat = pkgs.cudaPackages.overrideScope (
    _final: _prev: {
      cuda_compat = null;
      autoAddCudaCompatRunpath = disabledCudaCompatRunpathHook;
    }
  );

  # r[impl onix.llamacpp_server.metalium_backend]
  mkLlamacppPackage =
    selectedBackend:
    if selectedBackend == metaliumBackendName then
      metaliumPackage
    else if selectedBackend == "rocm" then
      pkgs.llamacpp-rocm-rpc
    else if selectedBackend == "rocm-dspark" then
      pkgs.llamacpp-rocm-dspark
    else if selectedBackend == "rocm-qwen4exp" then
      pkgs.llamacpp-rocm-qwen4exp
    else
      pkgs.llama-cpp.override {
        cudaSupport = selectedBackend == "cuda";
        cudaPackages = if selectedBackend == "cuda" then cudaPackagesWithoutCompat else { };
        rocmSupport = false;
        vulkanSupport = selectedBackend == "vulkan";
        rpcSupport = false;
      };

  llamaCppPackage = mkLlamacppPackage backend;
  llamaServer = "${llamaCppPackage}/bin/llama-server";

  optionalArgs = condition: args: lib.optionals condition args;
  optionalNumberArg =
    name: value:
    optionalArgs (value > disabledNumericOption) [
      name
      (toString value)
    ];
  optionalStringArg =
    name: value:
    optionalArgs (value != null) [
      name
      value
    ];

  serverArgs = [
    llamaServer
    "--host"
    host
    "--port"
    (toString port)
    "--model"
    modelPath
    "--alias"
    exposedModelName
    "--ctx-size"
    (toString contextSize)
    "--gpu-layers"
    (toString effectiveGpuLayers)
  ]
  ++ optionalArgs hasDraftModel [
    "--model-draft"
    draftModelPath
  ]
  ++ optionalArgs hasMultimodalProjector [
    "--mmproj"
    multimodalProjectorPath
  ]
  ++ optionalArgs flashAttention [
    "--flash-attn"
    "on"
  ]
  ++ optionalArgs metaliumBackendEnabled [
    "--flash-attn"
    "off"
    "--no-kv-offload"
  ]
  ++ optionalArgs noMmap [ "--no-mmap" ]
  ++ optionalArgs enableMetrics [ "--metrics" ]
  ++ optionalNumberArg "--threads" generationThreads
  ++ optionalNumberArg "--threads-batch" batchThreads
  ++ optionalNumberArg "--batch-size" batchSize
  ++ optionalNumberArg "--ubatch-size" ubatchSize
  ++ optionalNumberArg "--parallel" parallelSlots
  ++ optionalStringArg "--cache-type-k" cacheTypeK
  ++ optionalStringArg "--cache-type-v" cacheTypeV
  ++ extraArgs;

  downloadModel = pkgs.writeShellApplication {
    name = "${pullServiceName}-script";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
    ];
    text = ''
      set -euo pipefail

      model_dir=${lib.escapeShellArg modelsDir}
      mkdir -p "$model_dir"

      curl_auth_args=()
      auth_header_file=""
      cleanup_auth_header() {
        if [ -n "$auth_header_file" ]; then
          rm -f "$auth_header_file"
        fi
      }
      trap cleanup_auth_header EXIT

      ${lib.optionalString huggingFaceTokenRequired ''
        token="''${HF_TOKEN:-}"
        if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg stockSopsPlaceholder} ]; then
          echo "Hugging Face token for ${serviceName} is unset" >&2
          exit 1
        fi
        case "$token" in
          ${huggingFaceTokenPrefix}*) ;;
          *)
            echo "Hugging Face token for ${serviceName} is malformed" >&2
            exit 1
            ;;
        esac
        token_body="''${token#${huggingFaceTokenPrefix}}"
        case "$token_body" in
          ""|*[![:alnum:]]*)
            echo "Hugging Face token for ${serviceName} contains an invalid token body" >&2
            exit 1
            ;;
          *) ;;
        esac

        auth_header_file="$(mktemp)"
        chmod ${temporarySecretMode} "$auth_header_file"
        printf 'Authorization: Bearer %s\n' "$token" > "$auth_header_file"
        curl_auth_args=(--header "@$auth_header_file")
        unset HF_TOKEN token token_body

        if ! curl \
          --fail \
          --head \
          --location \
          --max-time ${toString accessProbeTimeoutSeconds} \
          --silent \
          --show-error \
          "''${curl_auth_args[@]}" \
          ${lib.escapeShellArg modelAccessProbeUrl} \
          > /dev/null; then
          echo "Hugging Face has not authorized access to ${modelRepo}" >&2
          exit 1
        fi
      ''}

      download_file() {
        local file="$1"
        local url="$2"
        local expected_sha256="$3"
        local target="''${model_dir}/''${file}"
        local partial="''${target}${partialSuffix}"

        verify_file() {
          [ -z "$expected_sha256" ] \
            || printf '%s  %s\n' "$expected_sha256" "$1" | sha256sum --check --status
        }

        if [ -f "$target" ] && verify_file "$target"; then
          echo "Model file is present and valid: ''${file}"
          return 0
        fi

        rm -f "$target"
        echo "Downloading model file: ''${file}"
        echo "URL: ''${url}"
        mkdir -p "$(dirname "$target")"

        curl \
          --fail \
          --location \
          --retry ${toString curlRetryCount} \
          --retry-all-errors \
          --retry-delay ${toString curlRetryDelaySeconds} \
          --continue-at - \
          --output "$partial" \
          "''${curl_auth_args[@]}" \
          "$url"

        if ! verify_file "$partial"; then
          rm -f "$partial"
          echo "Downloaded model hash does not match its declared SHA-256" >&2
          return 1
        fi

        chmod ${modelFileMode} "$partial"
        mv "$partial" "$target"
        echo "Download complete: ''${file}"
      }

      ${lib.concatMapStringsSep "\n" (
        download:
        "download_file ${lib.escapeShellArg download.file} ${lib.escapeShellArg download.url} ${
          lib.escapeShellArg (if download.sha256 == null then "" else download.sha256)
        }"
      ) modelDownloads}
      ${lib.optionalString draftFromPackage ''

        target="''${model_dir}/${draftModelFile}"
        if [ ! -f "$target" ]; then
          echo "Installing packaged draft model: ${draftModelFile}"
          install -m ${modelFileMode} ${pkgs.deepseek-v4-dspark-draft} "$target"
        else
          echo "Model file already present: ${draftModelFile}"
        fi
      ''}
    '';
  };

  checkModelFiles = pkgs.writeShellScript "${serviceName}-check-models" (
    lib.concatMapStringsSep "\n" (
      download:
      let
        path = "${modelsDir}/${download.file}";
      in
      if download.sha256 == null then
        "test -f ${lib.escapeShellArg path}"
      else
        "printf '%s  %s\\n' ${lib.escapeShellArg download.sha256} ${lib.escapeShellArg path} | ${pkgs.coreutils}/bin/sha256sum --check --status"
    ) modelDownloads
  );

  acpiPlatformProfile = "/sys/firmware/acpi/platform_profile";
  lockGpuClocks = pkgs.writeShellScript "${serviceName}-lock-gpu-clocks" ''
    if [ -w ${acpiPlatformProfile} ]; then
      echo performance > ${acpiPlatformProfile}
    fi
    ${pkgs.rocmPackages.rocm-smi}/bin/rocm-smi -d ${toString radeonDeviceIndex} --setperflevel high
  '';
in
{
  assertions = [
    {
      assertion = modelRepo != "";
      message = "llamacpp-server ${instanceName}: modelRepo must not be empty";
    }
    {
      assertion = modelFile != "";
      message = "llamacpp-server ${instanceName}: modelFile must not be empty";
    }
    {
      assertion = modelSha256 == null || builtins.match "[0-9a-f]{64}" modelSha256 != null;
      message = "llamacpp-server ${instanceName}: modelSha256 must be a lowercase SHA-256 value";
    }
    {
      assertion =
        extraModelSha256 == [ ] || builtins.length extraModelSha256 == builtins.length extraModelFiles;
      message = "llamacpp-server ${instanceName}: extraModelSha256 must be empty or align with extraModelFiles";
    }
    {
      assertion = lib.all (hash: builtins.match "[0-9a-f]{64}" hash != null) extraModelSha256;
      message = "llamacpp-server ${instanceName}: extraModelSha256 values must be lowercase SHA-256 values";
    }
    {
      assertion =
        multimodalProjectorSha256 == null
        || builtins.match "[0-9a-f]{64}" multimodalProjectorSha256 != null;
      message = "llamacpp-server ${instanceName}: multimodalProjectorSha256 must be a lowercase SHA-256 value";
    }
    {
      assertion = multimodalProjectorSha256 == null || hasMultimodalProjector;
      message = "llamacpp-server ${instanceName}: multimodalProjectorSha256 requires multimodalProjectorFile";
    }
    {
      assertion = lib.all isSafeRelativeModelPath modelFilePaths;
      message = "llamacpp-server ${instanceName}: model files must use safe relative paths without empty, dot, or parent components";
    }
    {
      assertion = (draftModelFile != "") == (draftModelRepo != "" || draftFromPackage);
      message = "llamacpp-server ${instanceName}: draftModelRepo and draftModelFile must be set together unless draftModelSource is package";
    }
    {
      assertion = !draftFromPackage || (pkgs.deepseek-v4-dspark-draft or null) != null;
      message = "llamacpp-server ${instanceName}: draftModelSource package requires the deepseek-v4-dspark-draft package";
    }
    {
      assertion = contextSize > 0;
      message = "llamacpp-server ${instanceName}: contextSize must be positive";
    }
    {
      assertion = gpuLayers >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: gpuLayers must not be negative";
    }
    {
      assertion = builtins.isInt metaliumDeviceId && metaliumDeviceId >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: metaliumDeviceId must be a non-negative integer";
    }
    {
      assertion = !metaliumTrace || metaliumBackendEnabled;
      message = "llamacpp-server ${instanceName}: metaliumTrace requires backend = metalium";
    }
    {
      assertion = !metaliumBackendEnabled || !flashAttention;
      message = "llamacpp-server ${instanceName}: Metalium requires flashAttention = false with CPU KV cache";
    }
    {
      assertion = !metaliumBackendEnabled || (cacheTypeK == null && cacheTypeV == null);
      message = "llamacpp-server ${instanceName}: Metalium requires default F16 CPU KV cache types";
    }
    {
      assertion = generationThreads >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: generationThreads must not be negative";
    }
    {
      assertion = batchThreads >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: batchThreads must not be negative";
    }
    {
      assertion = batchSize >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: batchSize must not be negative";
    }
    {
      assertion = ubatchSize >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: ubatchSize must not be negative";
    }
    {
      assertion = parallelSlots >= disabledNumericOption;
      message = "llamacpp-server ${instanceName}: parallelSlots must not be negative";
    }
  ];

  environment.systemPackages = [ llamaCppPackage ];

  # r[impl onix.aspen1.qwen_flash.download]
  clan.core.vars.generators = lib.mkIf huggingFaceTokenRequired {
    ${generatorName} = {
      files."env-file" = {
        secret = true;
        deploy = true;
        owner = "root";
        group = "root";
        mode = secretFileMode;
      };
      prompts.huggingface-token = {
        description = "Hugging Face read token authorized for ${modelRepo}";
        type = "hidden";
        persist = true;
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''
        token="$(tr -d '\r\n' < "$prompts/huggingface-token")"
        if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg stockSopsPlaceholder} ]; then
          echo "Hugging Face token for ${serviceName} is unset" >&2
          exit 1
        fi
        case "$token" in
          ${huggingFaceTokenPrefix}*) ;;
          *)
            echo "Hugging Face token for ${serviceName} is malformed" >&2
            exit 1
            ;;
        esac
        token_body="''${token#${huggingFaceTokenPrefix}}"
        case "$token_body" in
          ""|*[![:alnum:]]*)
            echo "Hugging Face token for ${serviceName} contains an invalid token body" >&2
            exit 1
            ;;
          *) ;;
        esac
        printf 'HF_TOKEN=%s\n' "$token" > "$out/env-file"
      '';
    };
  };

  systemd = {
    tmpfiles.rules = [
      "d ${modelsDir} ${stateDirectoryMode} root root -"
    ]
    ++ lib.optionals metaliumBackendEnabled [
      "d ${metaliumCacheDir} ${stateDirectoryMode} root root -"
      "d ${metaliumLogsDir} ${stateDirectoryMode} root root -"
    ];

    services = {
      ${pullServiceName} = {
        description = "Download llama.cpp model for ${instanceName}";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        before = [ "${serviceName}.service" ];
        wantedBy = lib.mkIf autoStart [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = pullRestartDelay;
          TimeoutStartSec = infiniteTimeout;
          StateDirectory = stateDirectory;
          StateDirectoryMode = stateDirectoryMode;
          ExecStart = lib.getExe downloadModel;
        }
        // lib.optionalAttrs huggingFaceTokenRequired {
          EnvironmentFile = envFile;
        };
      };

      ${serviceName} = {
        description = "llama.cpp OpenAI-compatible server (${instanceName})";
        path = lib.optionals hasMultimodalProjector [ pkgs.ffmpeg-headless ];
        after = [
          "network-online.target"
          "${pullServiceName}.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "${pullServiceName}.service" ];
        wantedBy = lib.mkIf autoStart [ "multi-user.target" ];

        serviceConfig = {
          ExecCondition = "${checkModelFiles}";
          ExecStartPre = lib.mkIf gpuPerformanceLock [ "${lockGpuClocks}" ];
          ExecStart = lib.escapeShellArgs serverArgs;
          Restart = "on-failure";
          RestartSec = serverRestartDelay;
          TimeoutStartSec = infiniteTimeout;
          User = "root";
          Group = "root";
          StateDirectory = stateDirectory;
          StateDirectoryMode = stateDirectoryMode;
        }
        // lib.optionalAttrs metaliumBackendEnabled {
          UnsetEnvironment = [
            "GGML_METALIUM_MESH_SHAPE"
            "TT_MESH_GRAPH_DESC_PATH"
          ];
        };

        # r[impl onix.llamacpp_server.metalium_safety]
        # r[impl onix.tenstorrent.model_process_isolation.devices]
        # r[impl onix.tenstorrent.model_process_isolation.state]
        environment = {
          HOME = stateDir;
        }
        // lib.optionalAttrs metaliumBackendEnabled {
          GGML_METALIUM_DEVICE_ID = "0";
          # r[impl onix.tenstorrent.model_performance.trace_replay]
          GGML_METALIUM_TRACE = metaliumTraceEnvironmentValue;
          TT_METAL_CACHE = metaliumCacheDir;
          TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS = "127.0.0.1:${toString metaliumInspectorPort}";
          TT_METAL_LOGS_PATH = metaliumLogsDir;
          TT_VISIBLE_DEVICES = toString metaliumDeviceId;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
