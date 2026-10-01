{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDir = "/var/lib/diffusion-gemma";
  runtime = builtins.fromJSON (builtins.readFile ./diffusion-gemma/runtime.json);
  modelPath = "/huggingface/hub/models--google--diffusiongemma-26B-A4B-it/snapshots/${runtime.modelRevision}";
  imageArchive = "${stateDir}/runtime-image.tar";
  docker = lib.getExe config.virtualisation.docker.package;
  prepareImage = pkgs.writeShellScript "prepare-diffusion-gemma-image" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/install -d -m 0750 ${stateDir} ${stateDir}/cache ${stateDir}/huggingface
    ${pkgs.coreutils}/bin/install -d -m 0700 ${stateDir}/docker-config
    if ! ${docker} image inspect ${lib.escapeShellArg runtime.imageId} >/dev/null 2>&1; then
      printf '%s  %s\n' ${lib.escapeShellArg runtime.imageArchiveSha256} ${lib.escapeShellArg imageArchive} |
        ${pkgs.coreutils}/bin/sha256sum --check -
      ${docker} load --input ${lib.escapeShellArg imageArchive}
    fi
  '';
  commonContainer = {
    image = runtime.imageId;
    pull = "never";
    networks = [ "host" ];
    environment = {
      HOME = "/tmp";
      HF_HOME = "/huggingface";
      HF_HUB_OFFLINE = "1";
      TRANSFORMERS_OFFLINE = "1";
      PYTHONUNBUFFERED = "1";
    };
    volumes = [ "${stateDir}/huggingface:/huggingface:ro" ];
    capabilities.ALL = false;
  };
  unitSettings = {
    environment.DOCKER_CONFIG = "${stateDir}/docker-config";
    serviceConfig = {
      ExecStartPre = lib.mkBefore [ prepareImage ];
      StateDirectory = "diffusion-gemma";
      StateDirectoryMode = "0750";
      RestartSec = 10;
    };
    unitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 3;
    };
  };
in
{
  # r[impl onix.diffusion-gemma.isolation]
  # Keep the retired Qwen unit masked while DiffusionGemma owns this GPU.
  systemd.services."llamacpp-server-qwen38-flash-next-aspen1".enable = lib.mkForce false;

  systemd.services."docker-diffusion-gemma" = unitSettings // {
    conflicts = [ "llamacpp-server-qwen38-flash-next-aspen1.service" ];
    wants = [ "docker-diffusion-gemma-structured.service" ];
  };
  systemd.services."docker-diffusion-gemma-structured" = unitSettings // {
    partOf = [ "docker-diffusion-gemma.service" ];
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.diffusion-gemma = commonContainer // {
      devices = [
        "/dev/kfd"
        "/dev/dri"
      ];
      environment = commonContainer.environment // {
        HIP_VISIBLE_DEVICES = "0";
        VLLM_ROCM_USE_AITER = "0";
        VLLM_USE_V2_MODEL_RUNNER = "1";
        VLLM_CACHE_ROOT = "/cache/vllm";
        TRITON_CACHE_DIR = "/cache/triton";
        TORCHINDUCTOR_CACHE_DIR = "/cache/inductor";
        OMP_NUM_THREADS = "8";
        HOME = "/cache";
      };
      volumes = commonContainer.volumes ++ [ "${stateDir}/cache:/cache" ];
      extraOptions = [
        "--read-only"
        "--security-opt=no-new-privileges:true"
        "--memory=88g"
        "--memory-swap=88g"
        "--shm-size=2g"
        "--tmpfs=/tmp:rw,nosuid,nodev,size=4g"
      ];
      # r[impl onix.diffusion-gemma.runtime]
      cmd = [
        "python3"
        "-m"
        "vllm.entrypoints.cli.main"
        "serve"
        modelPath
        "--served-model-name"
        "diffusiongemma"
        "--host"
        "127.0.0.1"
        "--port"
        "8000"
        "--dtype"
        "bfloat16"
        "--max-model-len"
        "4096"
        "--max-num-seqs"
        "1"
        "--max-num-batched-tokens"
        "4096"
        "--gpu-memory-utilization"
        "0.70"
        "--kv-cache-memory-bytes"
        "2147483648"
        "--attention-backend"
        "TRITON_ATTN"
        "--enforce-eager"
        "--enable-prefix-caching"
        "--async-scheduling"
        "--max-logprobs"
        "128"
        "--diffusion-config"
        ''{"canvas_length":256}''
        "--override-generation-config"
        ''{"max_new_tokens":null}''
        "--reasoning-parser"
        "gemma4"
        "--enable-auto-tool-choice"
        "--tool-call-parser"
        "gemma4"
      ];
    };
    containers.diffusion-gemma-structured = commonContainer // {
      dependsOn = [ "diffusion-gemma" ];
      extraOptions = [
        "--read-only"
        "--security-opt=no-new-privileges:true"
        "--memory=4g"
        "--memory-swap=4g"
        "--tmpfs=/tmp:rw,nosuid,nodev,size=256m"
      ];
      cmd = [
        "python3"
        "/opt/diffusion-reads/structured_server.py"
        "--upstream"
        "http://127.0.0.1:8000"
        "--model"
        "diffusiongemma"
        "--tokenizer"
        modelPath
        "--canvas"
        "256"
        "--host"
        "127.0.0.1"
        "--port"
        "8001"
      ];
    };
  };
}
