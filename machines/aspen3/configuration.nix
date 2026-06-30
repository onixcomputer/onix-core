{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  zfsHostId = "81f6943b";
  amdNpuKernelModule = "amdxdna";
  touchScreenI2cDevice = "i2c-ELAN9008:00";
  hardwareAccessMode = "0666";
  renderGroup = "render";
  mpvVolumeMaxPercent = 120;
  bluetoothAudioCodecs = [
    "ldac"
    "aac"
    "sbc_xq"
    "sbc"
  ];
  bluetoothAudioRoles = [
    "a2dp_sink"
    "a2dp_source"
    "bap_sink"
    "bap_source"
    "hsp_hs"
    "hsp_ag"
    "hfp_hf"
    "hfp_ag"
  ];
  ldacQualityMode = "hq";
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

    pipewire.wireplumber.extraConfig = {
      "10-bluez-audio-quality" = {
        "monitor.bluez.properties" = {
          "bluez5.roles" = bluetoothAudioRoles;
          "bluez5.codecs" = bluetoothAudioCodecs;
          "bluez5.enable-sbc-xq" = true;
          "bluez5.hfphsp-backend" = "native";
        };
      };
      "11-bluez-ldac-quality" = {
        "monitor.bluez.rules" = [
          {
            matches = [
              {
                "device.name" = "~bluez_card.*";
              }
            ];
            actions.update-props."bluez5.a2dp.ldac.quality" = ldacQualityMode;
          }
        ];
      };
    };
  };

  # udev rules for ROCm/vLLM and XDNA NPU access, matching the Strix Halo builder hosts.
  services.udev.extraRules = ''
    SUBSYSTEM=="kfd", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="drm", KERNEL=="renderD[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"
    SUBSYSTEM=="accel", KERNEL=="accel[0-9]*", GROUP="${renderGroup}", MODE="${hardwareAccessMode}"

    # Keep the internal ELAN9008 touchscreen armed as a suspend wake source so
    # firmware-level tap-to-wake works when supported.
    ACTION=="add|change", SUBSYSTEM=="i2c", KERNEL=="${touchScreenI2cDevice}", TEST=="power/wakeup", ATTR{power/wakeup}="enabled"
  '';

  users.users.brittonr.extraGroups = [ renderGroup ];

  home-manager.users.brittonr = {
    home.packages = with pkgs; [
      easyeffects
      evtest
      helvum
      libinput
      libwacom
      pwvucontrol
      qpwgraph
      rnote
      wev
      xournalpp
    ];

    programs.mpv.config."volume-max" = lib.mkForce mpvVolumeMaxPercent;
  };

  environment.systemPackages = with pkgs; [
    alsa-utils
    opentofu
  ];
}
