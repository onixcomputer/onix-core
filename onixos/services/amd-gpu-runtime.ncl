fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    {
      output.host = {
        # These are the exact buildEnv paths selected by the pinned NixOS
        # hardware.graphics module, recovered from its tmpfiles settings by
        # the package producer. Do not rebuild a second driver environment.
        tmpfiles = [
          m%"L+ /run/opengl-driver - - - - %{p."graphics-drivers"}"%,
          m%"L+ /run/opengl-driver-32 - - - - %{p."graphics-drivers-32bit"}"%,
        ],
        packages = [
          p."graphics-drivers",
          p."graphics-drivers-32bit",
          p."rocm-smi",
          p."rocm-clr-icd",
          p."vulkan-validation-layers",
          p.libdrm,
          p.rocminfo,
          p.clinfo,
          p.radeontop,
          p."nvtop-amd",
          p.btop,
          p."vulkan-tools",
          p."linux-firmware",
        ],
        groups = {
          render = { gid = 303 },
          video = { gid = 26 },
        },
        udev_rules."99-amd-gpu.rules" = m%"
          # KFD (Kernel Fusion Driver) for ROCm compute.
          SUBSYSTEM=="kfd", GROUP="render", MODE="0666"
          # DRM devices for GPU access.
          SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666"
          SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="render", MODE="0666"
        "%,
        environment = {
          LD_LIBRARY_PATH = m%"%{p."rocm-smi"}/lib:%{p.libdrm}/lib"%,
          HIP_VISIBLE_DEVICES = "0",
          HSA_ENABLE_SDMA = "0",
          HSA_OVERRIDE_GFX_VERSION = "11.5.1",
          PYTORCH_ROCM_ARCH = "gfx1151",
          OCL_ICD_VENDORS = m%"%{p."rocm-clr-icd"}/etc/OpenCL/vendors/"%,
          VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/amd_icd64.json:/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json",
          VK_LAYER_PATH = m%"%{p."vulkan-validation-layers"}/share/vulkan/explicit_layer.d"%,
          AMD_VULKAN_ICD = "RADV",
          VK_DRIVER_FILES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json",
          VK_INSTANCE_LAYERS = "VK_LAYER_KHRONOS_validation",
        },
        kernel = {
          modules = ["amdgpu"],
          initrd_modules = ["amdgpu"],
          params = ["amdgpu.gttsize=49152", "ttm.pages_limit=12582912"],
          firmware = [p."linux-firmware"],
        },
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/amd-gpu-runtime",
        description = "Configured AMD ROCm/OpenCL/Vulkan driver runtime, session environment, and device access policy for Aspen2.",
        categories = ["hardware", "runtime", "compute"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS uses inventory/tags/amd-gpu.nix and machines/aspen2/configuration.nix; the consumer carries the retained runtime outputs and device policy without restoring graphical services.",
          },
        ],
      },
      packages = [
        "graphics-drivers",
        "graphics-drivers-32bit",
        "rocm-smi=rocmPackages.rocm-smi",
        "rocm-clr-icd=rocmPackages.clr.icd",
        "vulkan-validation-layers",
        "libdrm",
        "rocminfo=rocmPackages.rocminfo",
        "clinfo",
        "radeontop",
        "nvtop-amd=nvtopPackages.amd",
        "btop",
        "vulkan-tools",
        "linux-firmware",
      ],
      roles.host = {},
    },
    impl = host_impl,
  }
  ) | onix.ServiceModule
