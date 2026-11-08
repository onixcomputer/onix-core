{
  config,
  pkgs,
  lib,
  ...
}:
{
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "amdgpu" ];
    };
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # ROCm packages for compute
        rocmPackages.clr.icd
        rocmPackages.rocm-runtime
        rocmPackages.rocm-device-libs
        rocmPackages.rocm-smi

        # Vulkan packages for graphics and compute
        vulkan-loader # Vulkan loader
        vulkan-validation-layers # Vulkan validation
        vulkan-extension-layer # Vulkan extensions

        # Mesa Vulkan driver (RADV) - alternative to AMDVLK
        mesa # Includes RADV Vulkan driver

        # Additional Vulkan tools
        vulkan-tools # vulkaninfo, vkcube, etc.
        vulkan-headers # Development headers
      ];
      extraPackages32 = with pkgs; [
        # driversi686Linux.amdvlk
        driversi686Linux.mesa
      ];
    };

    # AMD GPU specific settings
    amdgpu.opencl.enable = true;
  };

  environment = {
    sessionVariables.LD_LIBRARY_PATH = lib.mkForce (
      [
        "${pkgs.rocmPackages.rocm-smi}/lib"
        "${pkgs.libdrm}/lib"
      ]
      ++ lib.optionals config.hardware.sane.enable [ "/etc/sane-libs" ]
    );

    # System packages for AMD GPU development and monitoring
    systemPackages = with pkgs; [
      rocmPackages.rocm-smi
      rocmPackages.rocminfo
      clinfo # OpenCL device info
      radeontop # AMD GPU monitoring

      # Additional monitoring tools for AI workloads
      nvtopPackages.amd # AMD GPU monitoring (nvtop with AMD support)
      btop # System resource monitoring with GPU support

      # GPU stress testing and benchmarking
      vulkan-tools # Vulkan utilities
      # vkmark — broken in nixpkgs (Vulkan API incompatibility)
    ];

    # Environment variables for ROCm/OpenCL/Vulkan
    variables = {
      # ROCm/HIP settings
      HIP_VISIBLE_DEVICES = "0";

      # vLLM/ROCm optimization settings for Strix Halo (gfx1151)
      HSA_ENABLE_SDMA = "0"; # Prevents artifacts, improves stability for AI workloads
      HSA_OVERRIDE_GFX_VERSION = "11.5.1"; # Ensure gfx1151 is recognized
      PYTORCH_ROCM_ARCH = "gfx1151"; # Target architecture for PyTorch/vLLM

      # OpenCL settings
      OCL_ICD_VENDORS = "${pkgs.rocmPackages.clr.icd}/etc/OpenCL/vendors/";

      # Vulkan settings
      VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json:/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
      VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

      # Allow both RADV and AMDVLK drivers
      AMD_VULKAN_ICD = "RADV"; # Prefer RADV for better compatibility
      VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";

      # Enable Vulkan debug layers in development
      VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation";
    };
  };

  boot = {
    # Kernel modules for AMD GPU
    initrd.kernelModules = [ "amdgpu" ];
    kernelModules = [ "amdgpu" ];

    # TTM pages_limit: allow up to 100GB of system RAM to be GPU-mapped.
    # Default is ~50% (~64GB on 128GB systems).  LLM inference benefits from
    # larger GTT-backed allocations on unified memory (no perf penalty vs VRAM).
    # 100 GB = 26214400 pages (4 KiB each).  Leaves ~28GB for OS/CPU.
    # Ref: https://rocm.docs.amd.com/en/latest/how-to/system-optimization/rdna3-5.html
    extraModprobeConfig = ''
      options ttm pages_limit=26214400
    '';
  };

  # Users and groups for GPU access and monitoring
  users = {
    groups.prometheus-amd-gpu = { };
    users.prometheus-amd-gpu = {
      isSystemUser = true;
      group = "prometheus-amd-gpu";
      description = "AMD GPU Metrics Exporter User";
      extraGroups = [
        "render"
        "video"
        "node-exporter"
      ];
    };
  };

  # Systemd service + timer for GPU monitoring metrics.
  # Runs as a oneshot on a 5s timer instead of a long-lived loop —
  # gives systemd control over lifecycle, restarts, and resource accounting.
  systemd.services.amd-gpu-exporter = {
    description = "AMD GPU Metrics Exporter for Prometheus";
    after = [
      "network-online.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      User = "prometheus-amd-gpu";
      Group = "prometheus-amd-gpu";

      # Security settings
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [ "/var/lib/prometheus-node-exporter-text-files" ];

      # GPU access permissions
      SupplementaryGroups = [
        "render"
        "video"
        "node-exporter"
      ];

      ExecStart =
        let
          script = pkgs.writeShellApplication {
            name = "amd-gpu-exporter";
            runtimeInputs = [
              pkgs.rocmPackages.rocm-smi
              pkgs.jq
              pkgs.coreutils
            ];
            text = builtins.readFile ./amd-gpu-exporter.sh;
          };
        in
        lib.getExe script;
    };
  };

  systemd.timers.amd-gpu-exporter = {
    description = "Collect AMD GPU metrics every 5 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5s";
      OnUnitActiveSec = "5s";
      AccuracySec = "1s";
    };
  };
}
