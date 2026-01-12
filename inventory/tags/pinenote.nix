{ inputs, config, ... }:
{
  imports = [
    inputs.pinenote-nixos.nixosModules.default
  ];

  # Enable PineNote hardware support
  pinenote.config.enable = true;

  # ARM64 platform
  nixpkgs.hostPlatform = "aarch64-linux";

  # Waveform data - device-unique e-ink calibration
  # Backed up from /dev/mmcblk0p2 (2MB partition)
  clan.core.vars.generators.pinenote-waveform = {
    files.waveform = {
      secret = false;
      deploy = true;
    };
    # No script - manually populated from backup
    script = "";
  };

  # Deploy waveform to firmware location expected by rockchip-ebc driver
  systemd.tmpfiles.rules = [
    "d /lib/firmware/rockchip_ebc 0755 root root -"
    "C /lib/firmware/rockchip_ebc/waveform.bin 0644 root root - ${config.clan.core.vars.generators.pinenote-waveform.files.waveform.path}"
  ];
}
