{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
    ./buildbot.nix
  ];

  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # Kernel configuration for vLLM with large model support
  # AMD Strix Halo (gfx1151) unified memory configuration
  # See: https://dev.webonomic.nl/setting-up-unified-memory-for-strix-halo-correctly-on-ubuntu-25-04-or-25-10
  boot = {
    # For 128GB system: allocate ~124GB to GPU (leave 4GB for system)
    # Calculation: 124 * 1024 * 1024 * 1024 / 4096 = 32505856 pages
    # Note: Use ttm module (not amdttm) for consumer Ryzen APUs
    kernelParams = [
      "ttm.pages_limit=32505856"
      "ttm.page_pool_size=32505856"
    ];

    # Ensure latest kernel for full memory visibility (6.16.9+ required)
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # udev rules for GPU access - required for vLLM service
  services.udev.extraRules = ''
    # KFD (Kernel Fusion Driver) for ROCm compute
    SUBSYSTEM=="kfd", GROUP="render", MODE="0666"
    # DRM devices for GPU access
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="render", MODE="0666"
  '';

  # Install terraform/tofu for Keycloak terraform integration
  environment.systemPackages = with pkgs; [
    opentofu # OpenTofu (Terraform fork)
  ];

  services = {
    # Music Assistant - Music library and streaming service
    music-assistant = {
      enable = true;
    };
  };
}
