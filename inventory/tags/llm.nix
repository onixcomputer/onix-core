{ pkgs, ... }:
{
  # Enable Ollama service
  services.ollama = {
    enable = true;

    # Listen on all interfaces (default is localhost only)
    # Uncomment to expose to network
    # listenAddress = "0.0.0.0:11434";

    # Configure acceleration (auto-detects by default)
    acceleration = null; # Let Ollama auto-detect (set to "cuda" or "rocm" if needed)

    # Environment variables for Ollama
    environmentVariables = {
      # Set models directory (default: /var/lib/ollama/models)
      # OLLAMA_MODELS = "/path/to/models";

      # Set number of parallel requests
      OLLAMA_NUM_PARALLEL = "4";

      # Set max loaded models
      OLLAMA_MAX_LOADED_MODELS = "2";

      # Keep models in memory longer (in minutes, default 5)
      OLLAMA_KEEP_ALIVE = "10m";

      # GPU layer offloading - splits model between GPU and CPU
      # Adjust based on your GPU VRAM (higher = more GPU usage)
      OLLAMA_GPU_LAYERS = "35"; # Number of layers to offload to GPU

      # CPU thread allocation for inference
      OLLAMA_NUM_THREADS = "8"; # Adjust based on CPU cores

      # Memory settings for hybrid CPU/GPU inference
      OLLAMA_MAIN_GPU = "0"; # Primary GPU to use
      OLLAMA_TENSOR_SPLIT = "1.0"; # GPU memory allocation ratio (for multi-GPU)

      # Enable memory mapping for efficient RAM usage
      OLLAMA_MMAP = "true";

      # Flash attention for better memory efficiency
      OLLAMA_FLASH_ATTN = "true";
    };

    # Load specific models on startup (optional)
    # models = [ "llama3" "mistral" ];
  };

  # Install Ollama CLI and related tools
  environment.systemPackages = with pkgs; [
    ollama

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

  # Open firewall port if exposing to network
  # networking.firewall.allowedTCPPorts = [ 11434 ];

  # GPU support configuration (if using with nvidia tag)
  # The nvidia tag should handle most GPU setup, but Ollama needs:
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # Additional packages for GPU acceleration
      vaapiVdpau
      libvdpau-va-gl
    ];
  };

  # System configuration for better LLM performance
  boot.kernel.sysctl = {
    # Increase shared memory for large models
    "kernel.shmmax" = "68719476736"; # 64GB
    "kernel.shmall" = "16777216"; # 64GB / 4096

    # Optimize for throughput
    "vm.swappiness" = 10; # Reduce swapping
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
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

  # The ollama service will create its own user/group automatically
  # To add users to the ollama group for access:
  # users.users.<username>.extraGroups = [ "ollama" ];
}
