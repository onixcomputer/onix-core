{
  config,
  pkgs,
  ...
}:
{
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
    };
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Mesa for Zink (OpenGL-over-Vulkan) - fixes OrcaSlicer, KiCAD rendering issues
        mesa

        # Vulkan support
        vulkan-loader
        vulkan-validation-layers

        # NVIDIA-specific VA-API driver for video acceleration
        nvidia-vaapi-driver
      ];
      extraPackages32 = with pkgs; [
        driversi686Linux.mesa
      ];
    };

    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      powerManagement.finegrained = false;
      open = true;
      nvidiaSettings = true;
      # Stable driver recommended for RTX 50 series (Blackwell)
      # open = true is REQUIRED - proprietary modules don't support Blackwell
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  # Early kernel module loading for proper DRM initialization
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
    "nvidia_drm"
  ];

  # Kernel parameters for DRM framebuffer
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "nvidia-drm.fbdev=1"
  ];

  # Environment configuration for proper GPU rendering
  environment = {
    # Environment variables for proper GPU rendering
    variables = {
      # GBM backend for Wayland - required for proper EGL initialization
      GBM_BACKEND = "nvidia-drm";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";

      # VA-API with NVIDIA (for Firefox video acceleration)
      NVD_BACKEND = "direct";
      LIBVA_DRIVER_NAME = "nvidia";

      # Firefox Wayland - enable hardware acceleration
      MOZ_ENABLE_WAYLAND = "1";
      MOZ_WAYLAND_USE_VAAPI = "1";

      # Required for Firefox VA-API: disable RDD sandbox to allow libva access
      # Without this, VA-API decoding fails or produces green artifacts
      MOZ_DISABLE_RDD_SANDBOX = "1";

      # Electron apps (OrcaSlicer uses wxWidgets which may use GTK)
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
    };

    # System packages for GPU monitoring and utilities
    # Note: nvidia-smi is already included with the driver package
    systemPackages = with pkgs; [
      vulkan-tools
      libva-utils
      mesa-demos # OpenGL diagnostics (glxinfo, glxgears)
    ];

    # Wrapper scripts for applications that need Zink (Mesa OpenGL over Vulkan)
    # This fixes OrcaSlicer, FreeCAD, KiCAD rendering issues with NVIDIA
    shellAliases = {
      # Run OrcaSlicer with Zink to fix OpenGL rendering issues
      orca-slicer-zink = "__GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink orca-slicer";
      # Same for other CAD apps that might have issues
      openscad-zink = "__GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink openscad";
      kicad-zink = "__GLX_VENDOR_LIBRARY_NAME=mesa MESA_LOADER_DRIVER_OVERRIDE=zink GALLIUM_DRIVER=zink kicad";
    };
  };

  # Use sessionVariables in addition to environment.variables
  # sessionVariables are better inherited by display managers and Wayland sessions
  environment.sessionVariables = {
    # GBM backend for Wayland - required for proper EGL initialization
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # VA-API with NVIDIA (for Firefox video acceleration)
    NVD_BACKEND = "direct";
    LIBVA_DRIVER_NAME = "nvidia";

    # Firefox Wayland - enable hardware acceleration
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_WAYLAND_USE_VAAPI = "1";

    # Required for Firefox VA-API: disable RDD sandbox to allow libva access
    # Without this, VA-API decoding fails or produces green artifacts
    MOZ_DISABLE_RDD_SANDBOX = "1";

    # Electron apps (OrcaSlicer uses wxWidgets which may use GTK)
    ELECTRON_OZONE_PLATFORM_HINT = "auto";
  };
}
