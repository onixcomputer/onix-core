{
  pkgs,
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

        # Mesa Vulkan driver (RADV) - enabled by default
        mesa.drivers # Includes RADV Vulkan driver

        # Additional Vulkan tools
        vulkan-tools # vulkaninfo, vkcube, etc.
        vulkan-headers # Development headers
      ];
      extraPackages32 = with pkgs; [
        driversi686Linux.mesa.drivers
      ];
    };

    # AMD GPU specific settings
    amdgpu = {
      opencl.enable = true;
    };

    # Note: hardware.vulkan doesn't exist in NixOS
    # Vulkan support is handled through hardware.graphics.extraPackages
  };

  # System packages for AMD GPU development and monitoring
  environment.systemPackages = with pkgs; [
    rocmPackages.rocm-smi
    rocmPackages.rocminfo
    clinfo # OpenCL device info
    radeontop # AMD GPU monitoring

    # Additional monitoring tools for AI workloads
    nvtopPackages.amd # AMD GPU monitoring (nvtop with AMD support)
    btop # System resource monitoring with GPU support

    # GPU stress testing and benchmarking
    mesa-demos # OpenGL information (includes glxinfo)
    vulkan-tools # Vulkan utilities
    vkmark # Vulkan benchmarking tool
  ];

  # Environment variables for ROCm/OpenCL/Vulkan
  environment.variables = {
    # ROCm/HIP settings
    ROC_ENABLE_PRE_VEGA = "1";
    HIP_VISIBLE_DEVICES = "0";

    # OpenCL settings
    OCL_ICD_VENDORS = "${pkgs.rocmPackages.clr.icd}/etc/OpenCL/vendors/";

    # Vulkan settings
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json:/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
    VK_LAYER_PATH = "${pkgs.vulkan-validation-layers}/share/vulkan/explicit_layer.d";

    # Use RADV Vulkan driver (enabled by default)
    AMD_VULKAN_ICD = "RADV";
    VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";

    # Enable Vulkan debug layers in development
    VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation";
  };

  # Kernel modules for AMD GPU
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "amdgpu" ];

  # Users and groups for GPU access and monitoring
  users = {
    groups = {
      render = { };
      video = { };
      prometheus-amd-gpu = { };
    };
    users.prometheus-amd-gpu = {
      isSystemUser = true;
      group = "prometheus-amd-gpu";
      description = "AMD GPU Metrics Exporter User";
      extraGroups = [
        "render"
        "video"
      ];
    };
  };

  # Systemd service for GPU monitoring metrics
  systemd.services.amd-gpu-exporter = {
    description = "AMD GPU Metrics Exporter for Prometheus";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "prometheus-amd-gpu";
      Group = "prometheus-amd-gpu";
      Restart = "always";
      RestartSec = "10s";

      # Security settings
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;

      # GPU access permissions
      SupplementaryGroups = [
        "render"
        "video"
      ];

      ExecStart = pkgs.writeShellScript "amd-gpu-exporter" ''
        set -euo pipefail

        # Simple script to export AMD GPU metrics
        # This creates a basic text file with metrics that can be scraped

        METRICS_FILE="/tmp/amd_gpu_metrics.prom"

        while true; do
          # Get GPU utilization from rocm-smi
          if command -v rocm-smi >/dev/null 2>&1; then
            GPU_UTIL=$(rocm-smi --showuse --csv 2>/dev/null | tail -n +2 | cut -d',' -f2 | tr -d '%' || echo "0")
            GPU_TEMP=$(rocm-smi --showtemp --csv 2>/dev/null | tail -n +2 | cut -d',' -f2 | tr -d 'c' || echo "0")
            GPU_MEM=$(rocm-smi --showmemuse --csv 2>/dev/null | tail -n +2 | cut -d',' -f2 | tr -d '%' || echo "0")
            GPU_POWER=$(rocm-smi --showpower --csv 2>/dev/null | tail -n +2 | cut -d',' -f2 | tr -d 'W' || echo "0")

            # Write Prometheus metrics
            cat > "$METRICS_FILE.tmp" << EOF
        # HELP amd_gpu_utilization_percent AMD GPU utilization percentage
        # TYPE amd_gpu_utilization_percent gauge
        amd_gpu_utilization_percent{device="0"} $GPU_UTIL

        # HELP amd_gpu_temperature_celsius AMD GPU temperature in Celsius
        # TYPE amd_gpu_temperature_celsius gauge
        amd_gpu_temperature_celsius{device="0"} $GPU_TEMP

        # HELP amd_gpu_memory_utilization_percent AMD GPU memory utilization percentage
        # TYPE amd_gpu_memory_utilization_percent gauge
        amd_gpu_memory_utilization_percent{device="0"} $GPU_MEM

        # HELP amd_gpu_power_draw_watts AMD GPU power draw in watts
        # TYPE amd_gpu_power_draw_watts gauge
        amd_gpu_power_draw_watts{device="0"} $GPU_POWER
        EOF

            mv "$METRICS_FILE.tmp" "$METRICS_FILE"
          fi

          sleep 5
        done
      '';
    };
  };
}
