{ pkgs, ... }:
{
  # AMD NPU (Neural Processing Unit) integration for Ryzen AI MAX+ series
  # Enables multi-tier AI inference: NPU for small/fast tasks, GPU for large models

  # Environment configuration for NPU
  environment = {
    # Install NPU runtime and development tools
    systemPackages = with pkgs; [
      # ONNX Runtime with DirectML support for NPU acceleration
      onnxruntime

      # Python packages for NPU development
      python3Packages.onnx
      python3Packages.onnxruntime
      python3Packages.torch
      python3Packages.transformers

      # AMD AI toolchain (when available in nixpkgs)
      # rocmPackages.amd-smi  # Already included in amd-gpu tag

      # Monitoring tools for NPU
      htop
      iotop

      # Development tools for AI workloads
      python3Packages.numpy
      python3Packages.scipy
      python3Packages.matplotlib
    ];

    # Environment variables for NPU optimization
    variables = {
      # ONNX Runtime DirectML provider for NPU
      ORT_PROVIDERS = "DmlExecutionProvider,CPUExecutionProvider";

      # Enable NPU device for inference
      ONNX_NPU_DEVICE = "0";

      # Optimize for low-latency inference on NPU
      ORT_ENABLE_NPU_OPTIMIZATION = "1";
    };

    # Configuration file for NPU inference routing
    etc."npu-inference/config.yaml".text = ''
      # NPU Inference Configuration
      # Routes small/fast inference requests to NPU, large requests to GPU

      server:
        host: "0.0.0.0"
        port: 8080

      routing:
        # Route based on model size and request type
        small_models:
          max_parameters: "7B"
          max_context_length: 4096
          target: "npu"

        large_models:
          min_parameters: "7B"
          target: "gpu"
          fallback_url: "http://localhost:11434"

      npu:
        provider: "DirectML"
        device_id: 0
        optimization_level: "all"

      models:
        # Small models optimized for NPU
        - name: "phi-2"
          size: "2.7B"
          format: "onnx"
          target: "npu"

        - name: "code-completion"
          size: "1.3B"
          format: "onnx"
          target: "npu"

        # Large models routed to GPU
        - name: "qwen2.5:32b"
          size: "32B"
          target: "gpu"
          url: "http://localhost:11434"
    '';
  };

  # Systemd service for NPU inference serving
  systemd.services.npu-inference = {
    description = "NPU Inference Service for Small Model Serving";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "npu-inference";
      Group = "npu-inference";
      Restart = "always";
      RestartSec = "10s";

      # Resource limits for NPU service
      MemoryMax = "4G";
      CPUQuota = "200%"; # Allow up to 2 CPU cores

      # Security settings
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;

      # Working directory
      WorkingDirectory = "/var/lib/npu-inference";
      StateDirectory = "npu-inference";

      # Environment
      Environment = [
        "ORT_PROVIDERS=DmlExecutionProvider,CPUExecutionProvider"
        "ONNX_NPU_DEVICE=0"
        "ORT_ENABLE_NPU_OPTIMIZATION=1"
      ];

      ExecStart = pkgs.writeShellScript "npu-inference-server" ''
        set -euo pipefail

        # Simple HTTP server for NPU inference
        # This is a placeholder - actual implementation would use
        # FastAPI, Flask, or similar framework

        echo "Starting NPU inference server..."
        echo "NPU server would run on port 8080"
        echo "Handling small model inference requests via DirectML/NPU"

        # Keep service running (replace with actual server)
        while true; do
          sleep 30
          echo "NPU inference service running..."
        done
      '';
    };
  };

  # Create user and group for NPU inference service
  users.groups.npu-inference = { };
  users.users.npu-inference = {
    isSystemUser = true;
    group = "npu-inference";
    home = "/var/lib/npu-inference";
    createHome = true;
    description = "NPU Inference Service User";

    # Add to render and video groups for GPU access
    extraGroups = [
      "render"
      "video"
    ];
  };

  # Open firewall port for NPU inference API
  networking.firewall.allowedTCPPorts = [ 8080 ];

  # Kernel parameters for NPU optimization
  boot.kernel.sysctl = {
    # Optimize for low-latency inference
    "kernel.sched_latency_ns" = "1000000"; # 1ms scheduling latency
    "kernel.sched_min_granularity_ns" = "100000"; # 0.1ms minimum granularity

    # Memory optimization for small model inference
    "vm.swappiness" = "10"; # Prefer RAM over swap for NPU workloads
  };

  # Systemd service for NPU model optimization
  systemd.services.npu-model-optimizer = {
    description = "NPU Model Optimization and Conversion Service";
    after = [ "npu-inference.service" ];
    wants = [ "npu-inference.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "npu-inference";
      Group = "npu-inference";
      WorkingDirectory = "/var/lib/npu-inference";

      ExecStart = pkgs.writeShellScript "npu-model-optimizer" ''
        set -euo pipefail

        echo "NPU Model Optimization Service Starting..."

        # Create model directories
        mkdir -p /var/lib/npu-inference/models/onnx
        mkdir -p /var/lib/npu-inference/models/quantized

        echo "Model directories created for NPU optimization"

        # Future: Convert popular small models to ONNX format optimized for NPU
        # Examples:
        # - Code completion models (CodeT5, etc.)
        # - Small chat models (phi-2, etc.)
        # - Classification models
        # - Embedding models

        echo "NPU model optimization completed"
      '';

      # Restart policy
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Activation script to set up NPU inference environment
  system.activationScripts.npu-setup = ''
    # Ensure NPU inference directories exist with correct permissions
    mkdir -p /var/lib/npu-inference/models/{onnx,quantized}
    mkdir -p /var/lib/npu-inference/logs
    mkdir -p /var/lib/npu-inference/cache

    chown -R npu-inference:npu-inference /var/lib/npu-inference
    chmod -R 755 /var/lib/npu-inference

    # Create symbolic link to NPU config for easy access
    ln -sf /etc/npu-inference/config.yaml /var/lib/npu-inference/config.yaml || true
  '';
}
