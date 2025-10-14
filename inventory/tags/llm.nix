{ pkgs, ... }:
let
  # Custom goose-cli with latest version (1.9.3) to fix streaming issues
  goose-cli-latest = pkgs.rustPlatform.buildRustPackage rec {
    pname = "goose-cli";
    version = "1.9.3";

    src = pkgs.fetchFromGitHub {
      owner = "block";
      repo = "goose";
      rev = "v${version}";
      hash = "sha256-cw4iGvfgJ2dGtf6om0WLVVmieeVGxSPPuUYss1rYcS8=";
    };

    cargoHash = "sha256-/HaxjQDrBYKLP5lamx7TIbYUtIdCfbqZ5oQ1rK4T8uA=";

    nativeBuildInputs = with pkgs; [
      pkg-config
      protobuf
    ];
    buildInputs = with pkgs; [ dbus ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.xorg.libxcb ];

    doCheck = false; # Tests require network access

    meta = {
      description = "Open-source, extensible AI agent";
      homepage = "https://github.com/block/goose";
      license = pkgs.lib.licenses.asl20;
      mainProgram = "goose";
    };
  };
in
{
  # Enable Ollama service
  services.ollama = {
    enable = true;

    # Listen on all interfaces for network access
    host = "0.0.0.0";
    port = 11434;

    # Configure acceleration for AMD GPU
    acceleration = "rocm"; # Enable ROCm acceleration for AMD GPUs

    # Environment variables for Ollama with AMD GPU optimization
    environmentVariables = {
      # Set models directory (default: /var/lib/ollama/models)
      # OLLAMA_MODELS = "/path/to/models";

      # Set number of parallel requests (optimized for large models)
      OLLAMA_NUM_PARALLEL = "8";

      # Set max loaded models (AMD unified memory can handle more)
      OLLAMA_MAX_LOADED_MODELS = "6"; # Increased for unified memory architecture

      # Keep models in memory longer for better performance
      OLLAMA_KEEP_ALIVE = "30m";

      # GPU layer offloading - use all available GPU layers
      OLLAMA_GPU_LAYERS = "99"; # Use all available GPU layers

      # CPU thread allocation - optimized for Ryzen AI MAX+
      OLLAMA_NUM_THREADS = "24"; # Increased for high-core Ryzen AI MAX+

      # Memory settings for unified memory architecture
      OLLAMA_MAIN_GPU = "0"; # Primary GPU to use
      OLLAMA_TENSOR_SPLIT = "1.0"; # Single GPU configuration

      # AMD-specific optimizations for unified memory
      OLLAMA_GPU_MEMORY_FRACTION = "0.85"; # Use 85% of available unified memory for GPU

      # Enable memory mapping for efficient RAM usage (important for unified memory)
      OLLAMA_MMAP = "true";

      # Flash attention for better memory efficiency
      OLLAMA_FLASH_ATTN = "true";

      # ROCm-specific environment variables
      ROC_ENABLE_PRE_VEGA = "1"; # Enable support for RDNA GPUs
      HIP_VISIBLE_DEVICES = "0"; # Use first GPU device
      HSA_OVERRIDE_GFX_VERSION = "11.0.0"; # RDNA 3 architecture support

      # Vulkan compute support (alternative to ROCm)
      OLLAMA_VULKAN_DEVICE = "0"; # Use first Vulkan device
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";

      # Enable both ROCm and Vulkan for maximum compatibility
      OLLAMA_COMPUTE_BACKENDS = "rocm,vulkan"; # Try ROCm first, fallback to Vulkan
    };

    # Models directory (models will be downloaded via systemd service)
    models = "/var/lib/ollama/models";
  };

  # Install Ollama CLI and related tools
  environment.systemPackages = with pkgs; [
    ollama
    goose-cli-latest # AI coding assistant with latest version (1.9.3) - should fix streaming issues
    opencode # AI coding agent that works well with Ollama

    # Optional: GUI frontends for Ollama
    # open-webui # Web UI for Ollama
    # oterm # Terminal UI for Ollama

    # Tools for distributed/parallel inference
    # llama-cpp # CPU/GPU hybrid inference with fine control
    # vllm # High-throughput serving with PagedAttention
    # text-generation-webui # Gradio web UI with multi-backend support

    # Monitoring tools
    nvtopPackages.full # GPU monitoring
    btop # System resource monitoring
    ncdu # Disk usage for model storage
  ];

  # Open firewall port for network access
  networking.firewall.allowedTCPPorts = [ 11434 ];

  # GPU support configuration (works with both nvidia and amd-gpu tags)
  # The gpu tag should handle most GPU setup, but Ollama needs additional packages:
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # Additional packages for GPU acceleration (cross-platform)
      vaapiVdpau
      libvdpau-va-gl

      # AMD-specific packages for LLM workloads
      rocmPackages.clr
      rocmPackages.hipblas
      rocmPackages.rocblas
    ];
  };

  # System configuration for better LLM performance
  # Only LLM-specific settings that don't conflict with machine configs
  boot.kernel.sysctl = {
    # Increase shared memory for large models (LLM-specific setting)
    "kernel.shmmax" = "68719476736"; # 64GB - Required for large model loading
    "kernel.shmall" = "16777216"; # 64GB / 4096 - Shared memory segments

    # Note: vm.swappiness, vm.dirty_ratio, etc. are configured per-machine
    # as they depend on specific hardware and use case requirements
  };

  # Additional systemd service configuration (optional)
  # The ollama module provides good defaults, but you can override:
  # systemd.services.ollama = {
  #   serviceConfig = {
  #     # Resource limits for large models
  #     LimitNOFILE = "1048576";
  #     LimitMEMLOCK = "infinity";
  #   };
  # };

  # Optional: Enable Open WebUI for Ollama
  # services.open-webui = {
  #   enable = true;
  #   port = 3000;
  #   host = "0.0.0.0";
  #   environment = {
  #     OLLAMA_API_BASE_URL = "http://localhost:11434/api";
  #   };
  # };

  # Goose configuration for all users
  environment.etc."goose/config.yaml".text = ''
    provider: ollama
    model: qwen2.5:7b
    endpoint: http://aspen1:11434
    context_length: 32768
    temperature: 0.7
    max_tokens: 4096
    timeout: 300

    # Performance settings
    parallel_requests: 2
    stream: false

    # Enable useful extensions (optional - will fail gracefully if not available)
    extensions:
      - file_operations
      - terminal_commands
      - code_generation
  '';

  # Opencode configuration for ollama integration
  environment.etc."opencode/opencode.json".text = ''
    {
      "$schema": "https://opencode.ai/config.json",
      "provider": {
        "ollama": {
          "npm": "@ai-sdk/openai-compatible",
          "name": "Ollama (aspen1)",
          "options": {
            "baseURL": "http://aspen1:11434/v1"
          },
          "models": {
            "qwen2.5:7b": {
              "name": "Qwen 2.5 7B"
            },
            "qwen2.5:32b": {
              "name": "Qwen 2.5 32B"
            }
          }
        }
      }
    }
  '';

  # Global goose hints for Onix-Core project
  environment.etc."goosehints".text = ''
    # Onix-Core NixOS Configuration Project

    This is a NixOS configuration repository using the Onix framework.

    ## Key Information:
    - Uses Nix flakes and NixOS modules
    - Machine configurations in inventory/core/machines.nix
    - Service tags in inventory/tags/
    - Focus on system administration and DevOps tasks
    - Prefer absolute paths when referencing files

    ## Common Tasks:
    - Configuring NixOS services
    - Managing machine deployments with `clan deploy <machine>`
    - Working with systemd services
    - GPU/AI workload optimization
    - Network and firewall configuration

    ## Code Style:
    - Use Nix expressions with proper formatting
    - Follow existing patterns in the codebase
    - Include comments for complex configurations
    - Test configurations before deployment
  '';

  # Systemd service to ensure models are downloaded and ready
  systemd.services.ollama-model-preload = {
    description = "Preload Ollama models for LLM services";
    after = [ "ollama.service" ];
    wants = [ "ollama.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "ollama";
      Group = "ollama";
      Environment = [ "HOME=/var/lib/ollama" ];
      ExecStart = pkgs.writeShellScript "preload-models" ''
        set -euo pipefail

        # Wait for ollama service to be ready
        timeout=60
        while ! ${pkgs.curl}/bin/curl -s http://localhost:11434/api/tags > /dev/null; do
          echo "Waiting for Ollama API to be ready..."
          sleep 2
          timeout=$((timeout - 2))
          if [ $timeout -le 0 ]; then
            echo "Timeout waiting for Ollama API"
            exit 1
          fi
        done

        echo "Ollama API is ready"

        # Check if qwen2.5:32b is available, if not try alternatives
        if ! ${pkgs.ollama}/bin/ollama list | grep -q "qwen2.5:32b"; then
          echo "Downloading qwen2.5:32b model..."
          if ! ${pkgs.ollama}/bin/ollama pull qwen2.5:32b; then
            echo "Failed to download qwen2.5:32b, trying qwen2.5:14b..."
            if ! ${pkgs.ollama}/bin/ollama pull qwen2.5:14b; then
              echo "Failed to download qwen2.5:14b, trying qwen:32b..."
              ${pkgs.ollama}/bin/ollama pull qwen:32b || echo "Warning: No Qwen models could be downloaded"
            fi
          fi
        else
          echo "qwen2.5:32b model already available"
        fi

        # Create optimized modelfile if model was downloaded
        model_name=$(${pkgs.ollama}/bin/ollama list | ${pkgs.gnugrep}/bin/grep -E "qwen.*32b|qwen.*14b" | ${pkgs.coreutils}/bin/head -1 | ${pkgs.gawk}/bin/awk '{print $1}' || echo "")
        if [ -n "$model_name" ]; then
          echo "Creating optimized configuration for $model_name..."

          # Create temporary modelfile
          cat > /tmp/QwenOptimized << EOF
        FROM $model_name

        # Optimized parameters for high-performance setup
        PARAMETER num_ctx 32768              # Extended context
        PARAMETER num_predict -1             # No generation limit
        PARAMETER temperature 0.7            # Balanced creativity
        PARAMETER top_k 40
        PARAMETER top_p 0.9
        PARAMETER repeat_penalty 1.1
        PARAMETER num_thread 16              # Match OLLAMA_NUM_THREADS

        # System message for coding assistance
        SYSTEM """You are Qwen, a helpful AI assistant with strong capabilities in code analysis, system administration, and technical problem-solving. When working with NixOS configurations and system administration tasks, provide accurate, secure, and maintainable solutions."""
        EOF

          # Create optimized model
          if ${pkgs.ollama}/bin/ollama create qwen-optimized -f /tmp/QwenOptimized; then
            echo "Optimized model 'qwen-optimized' created successfully"
          else
            echo "Warning: Could not create optimized model"
          fi

          rm -f /tmp/QwenOptimized
        fi

        echo "Model preload service completed successfully"
      '';

      # Restart policy for robustness
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };

  # Add users to ollama group for CLI access
  users.users.brittonr.extraGroups = [ "ollama" ];

  # Create user-specific AI tool configs
  system.activationScripts.ai-user-configs = ''
        # Ensure config directories exist for users
        for user in brittonr; do
          if [ -d "/home/$user" ]; then
            # Goose configuration
            mkdir -p "/home/$user/.config/goose"
            if [ ! -f "/home/$user/.config/goose/config.yaml" ] || [ "/etc/goose/config.yaml" -nt "/home/$user/.config/goose/config.yaml" ]; then
              cp "/etc/goose/config.yaml" "/home/$user/.config/goose/config.yaml"
              chown "$user:users" "/home/$user/.config/goose/config.yaml"
            fi

            # Opencode configuration
            mkdir -p "/home/$user/.config/opencode"
            if [ ! -f "/home/$user/.config/opencode/opencode.json" ] || [ "/etc/opencode/opencode.json" -nt "/home/$user/.config/opencode/opencode.json" ]; then
              cp "/etc/opencode/opencode.json" "/home/$user/.config/opencode/opencode.json"
              chown "$user:users" "/home/$user/.config/opencode/opencode.json"
            fi

            # Set default opencode config
            cat > "/home/$user/.config/opencode/config.json" << 'EOFC'
    {
      "$schema": "https://opencode.ai/config.json",
      "model": "ollama/qwen2.5:7b",
      "theme": "opencode",
      "autoshare": false,
      "autoupdate": true
    }
    EOFC
            chown "$user:users" "/home/$user/.config/opencode/config.json"
          fi
        done
  '';
}
