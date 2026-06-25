{
  inputs,
  pkgs,
  ...
}:
let
  zfsHostId = "81f6943b";
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
  };

  services = {
    # The ASUS Flow module enables GPU switching by default for GV302X. This
    # GZ302EAC target has the integrated Radeon 8060S, so no mux daemon is needed.
    supergfxd.enable = false;

    # Override the greeter tag's Hyprland default with the Niri session used by
    # the other interactive Niri hosts.
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";
  };

  # udev rules for ROCm/vLLM access, matching the Strix Halo builder hosts.
  services.udev.extraRules = ''
    SUBSYSTEM=="kfd", GROUP="render", MODE="0666"
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="render", MODE="0666"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="render", MODE="0666"
  '';

  environment.systemPackages = with pkgs; [
    opentofu
  ];
}
