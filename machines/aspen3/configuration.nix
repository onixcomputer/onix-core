{
  inputs,
  pkgs,
  ...
}:
let
  zfsHostId = "81f6943b";
  amdNpuKernelModule = "amdxdna";
  hardwareAccessMode = "0666";
  renderGroup = "render";
in
{
  imports = [
    ./disko.nix
    inputs.nixos-hardware.nixosModules.asus-flow-gv302x-amdgpu
  ];

  networking = {
    hostName = "aspen3";
    hostId = zfsHostId;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages;
    supportedFilesystems = [ "zfs" ];
    # Expose the Strix Halo Ryzen AI/XDNA NPU as /dev/accel/accel*.
    kernelModules = [ amdNpuKernelModule ];
  };

  services = {
    # The ASUS Flow module enables GPU switching by default for GV302X. This
    # GZ302EAC target has the integrated Radeon 8060S, so no mux daemon is needed.
    supergfxd.enable = false;

    # Enable Thunderbolt/USB4 authorization for user-security domains.
    hardware.bolt.enable = true;

    # Windows Hello-style face authentication using the built-in IR camera.
    # Keep password fallback available; the IR stream is /dev/video2 on GZ302EAC.
    howdy = {
      enable = true;
      control = "sufficient";
      settings.video.device_path = "/dev/video2";
    };
    linux-enable-ir-emitter = {
      enable = true;
      device = "video2";
    };

    # Bridge the tablet accelerometer through iio-sensor-proxy into Niri.
    iio-niri.enable = true;

    # Override the greeter tag's Hyprland default with the Niri session used by
    # the other interactive Niri hosts.
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";
  };

  # udev rules for ROCm/vLLM and XDNA NPU access, matching the Strix Halo builder hosts.
  services.udev.extraRules = ''
    SUBSYSTEM=="kfd", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
  '';

  users.users.brittonr.extraGroups = [ renderGroup ];

  environment.systemPackages = with pkgs; [
    opentofu
  ];
}
