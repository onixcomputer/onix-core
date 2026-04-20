{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
  ];

  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # LLM-optimized: TTM pages_limit set in amd-gpu tag (100GB GTT-backed).
  # Keep BIOS VRAM carve-out small (0.5GB); unified memory has no perf penalty.
  boot = {
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
