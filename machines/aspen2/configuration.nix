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
    hostName = "aspen2";
  };

  time.timeZone = "America/New_York";

  # CPU-oriented memory configuration — no TTM overrides, so the GPU gets
  # only its default firmware VRAM carveout and the rest stays with the CPU.
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
