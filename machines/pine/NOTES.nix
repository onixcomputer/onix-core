# PineNote Technical Reference
#
# PINE64 PineNote E-Ink Tablet - Hardware and Software Documentation
# Source: https://pine64.org/documentation/PineNote/_full/
# Generated: 2026-01-11
#
# This file documents hardware specifications, driver status, and NixOS
# configuration considerations for the PineNote. It is NOT a Nix module -
# it's a reference document in .nix format for easy access during development.

{
  hardware = {
    # Display - E-Ink ED103TC2
    display = {
      panel = "E-Ink ED103TC2";
      size = "10.3 inches";
      resolution = "1404 x 1872";
      dpi = 227;
      grayscale = "16-level";
      frontlight = {
        levels = 36;
        type = "cold/warm adjustable";
        driver = "LM3630A";
      };
      touch = {
        capacitive = "Cypress CYTTSP5 (mainline 6.2+)";
        digitizer = "Wacom SUDE-10S15MI-01X via i2c_hid_of (mainline)";
      };
    };

    # System-on-Chip - Rockchip RK3566
    soc = {
      model = "Rockchip RK3566";
      cpu = "Quad-core ARM Cortex-A55 @ 1.8 GHz";
      gpu = "Mali-G52 2EE Bifrost @ 800 MHz";
      npu = "0.8 TOPS neural acceleration";
      process = "22nm FD-SOI";
      cache = {
        l3 = "512KB";
        l1_icache = "32KB per core";
        l1_dcache = "32KB per core";
      };
    };

    # Memory and Storage
    memory = {
      ram = "4GB LPDDR4";
      storage = "128GB eMMC (Biwin BWCTASC41P128G)";
      device = "/dev/mmcblk0";
    };

    # Connectivity
    connectivity = {
      wifi = {
        standards = "802.11a/b/g/n/ac dual-band (2.4/5 GHz)";
        module = "Azurewave CM256SM (Broadcom BCM4345C0)";
        driver = "brcmfmac (mainline)";
      };
      bluetooth = {
        version = "5.0 LE";
        driver = "brcmfmac";
      };
      usb = {
        type = "USB-C";
        speed = "USB 2.0 (480 Mbps max)";
        power = "5V/3A charging";
        displayPort = false;
      };
    };

    # Audio
    audio = {
      speakers = "Stereo";
      microphones = "4x DMIC";
      amplifier = "Awinic AW87318 Class-K";
      codec = "RK817 internal";
    };

    # Sensors
    sensors = {
      accelerometer = {
        model = "Silan SC7A20";
        driver = "st-accel-i2c (mainline 5.18+)";
      };
      hallSensor = {
        location = "U9009 (back, top-right quadrant)";
        function = "Maskrom mode entry";
      };
    };

    # Power
    power = {
      battery = "4000 mAh LiPo";
      mainPMIC = "Rockchip RK817";
      einkPMIC = "TI TPS65185";
    };

    # Physical
    physical = {
      dimensions = "191.1 x 232.5 x 7.4 mm";
      weight = "438g";
    };
  };

  # Linux Driver Status
  drivers = {
    # Mainlined drivers
    mainline = {
      touchscreen = "cyttsp5 (kernel 6.2+)";
      digitizer = "i2c_hid_of";
      wifi_bluetooth = "brcmfmac";
      accelerometer = "st-accel-i2c (kernel 5.18+)";
      backlight = "lm3630a";
      gpu = "panfrost (disabled upstream pending EBC)";
    };

    # Drivers requiring custom kernel
    custom = {
      eink_display = {
        driver = "rockchip-ebc";
        status = "RFC/WIP - NOT mainlined";
        kernel = "github.com/m-weigand/linux branch_pinenote_6-6-30";
        alternative = "github.com/hrdl/linux (per-pixel scheduling)";
      };
      eink_pmic = {
        driver = "tps65185";
        status = "In development";
      };
      suspend_resume = {
        driver = "rockchip-sip";
        status = "Requires downstream TF-A - NOT mainlinable";
      };
      rga_graphics = {
        driver = "rga (v4l2)";
        status = "WIP - hardware dithering/Y4";
      };
    };
  };

  # E-Ink Display Configuration
  eink = {
    # rockchip-ebc driver parameters
    driverParams = {
      direct_mode = "Direct mode control";
      auto_refresh = "Automatic refresh triggers";
      refresh_threshold = "Pixel change threshold";
      split_area_limit = "Area tiling for performance";
      panel_reflection = "0 for correct orientation (fixes inverted touch)";
      dclk_select = "Display clock selection";
    };

    # Refresh modes
    refreshModes = {
      A1 = "Fast black/white (<100ms), limited grayscale";
      A2 = "Balanced speed/quality";
      GC16 = "Highest quality (>500ms)";
      GL16 = "Reduced ghosting";
      GLR16 = "Full waveform refresh";
    };

    # Critical: Device-unique waveform data
    waveform = {
      location = "Dedicated 2MB partition";
      purpose = "E-ink calibration (device-unique)";
      warning = "MUST backup before any repartitioning";
    };
  };

  # Boot Process
  boot = {
    # UART configuration for serial console
    uart = {
      baudRate = 1500000;
      format = "8N1, no flow control";
      pins = "SBU1 (A8) = UART2_TX, SBU2 (B8) = UART2_RX";
      ccBias = "Requires 1K ohm pull-ups to 3.3V";
    };

    # U-Boot extlinux.conf example
    extlinux = ''
      timeout 10
      default MAINLINE
      label MAINLINE
        kernel /vmlinuz
        fdt /rk3566-pinenote.dtb
        initrd /initramfs
        append earlycon console=tty0 console=ttyS2,1500000n8
    '';

    # Maskrom entry methods
    maskrom = {
      magnet = "Hall sensor U9009 in top-right quadrant (back)";
      uboot = "rockusb 0 mmc 0 command via UART";
      testPoint = "Short TP1301 (GND) + TP1302 (eMMC_D0)";
    };

    # October 2024 batch U-Boot fix
    ubootFix = {
      issue = "Factory U-Boot had suspend/resume bugs";
      solution = "cd /root/uboot && bash install_stable_1056mhz_uboot.sh";
    };
  };

  # Partition Layout (Community Edition default)
  partitions = {
    # WARNING: This is the FACTORY layout - DO NOT use with disko
    # disko.nix uses a different layout optimized for NixOS
    factory = {
      "0_uboot" = "64 MB - Bootloader";
      "1_waveform" = "2 MB - E-ink calibration (CRITICAL - backup this!)";
      "2_uboot_env" = "1 MB - U-Boot environment";
      "3_logo" = "64 MB - Boot splash";
      "4_os1" = "14.65 GB - Primary OS";
      "5_os2" = "14.65 GB - Alternative OS";
      "6_data" = "85.82 GB - User data";
    };
  };

  # Firmware Requirements
  firmware = {
    wifi_bluetooth = {
      source = "LibreELEC firmware versions recommended";
      files = [
        "brcmfmac43455-sdio.pine64,pinenote-v1.2.txt"
        "brcmfmac43455-sdio.pine64,pinenote-v1.2.bin"
      ];
    };
    waveform = {
      note = "Device-unique, stored in dedicated partition";
      action = "Backup mandatory before any modifications";
    };
  };

  # Known Issues and Workarounds
  issues = {
    suspendBroken = {
      affected = "October 2024 batch";
      workaround = "Flash stable U-Boot from /root/uboot/";
    };

    touchscreenInverted = {
      workaround = "rockchip_ebc.panel_reflection=0 kernel parameter";
    };

    bluetoothAudioStutter = {
      workaround = "Modified device tree + max-speed=3000000";
    };

    chargingLED = {
      issue = "White LED bleeds through case";
      workaround = "Software LED disable when screen active";
    };
  };

  # Input Device Configuration
  input = {
    # Sway pen input transformation
    sway = ''
      input "type:table_tool" calibration_matrix -1 0 1 0 -1 1
    '';

    # X.org configuration
    xorg = ''
      Section "InputClass"
          Identifier "tt21000"
          MatchProduct "tt21000"
          MatchIsTouchscreen "on"
          Driver "evdev"
      EndSection
      Section "InputClass"
          Identifier "RotateTouch"
          MatchProduct "w9013"
          Option "TransformationMatrix" "-1 0 1 0 -1 1 0 0 1"
      EndSection
    '';
  };

  # NixOS-Specific Resources
  nixos = {
    # Primary NixOS module (used in this config)
    primaryModule = {
      repo = "github:WeraPea/pinenote-nixos";
      usage = "inputs.pinenote-nixos.nixosModules.default";
      features = [
        "PineNote-specific kernel and modules"
        "E-ink display driver support"
        "Cross-compilation support for aarch64"
      ];
    };

    # Alternative community projects
    alternatives = {
      tpwrules = {
        repo = "github:tpwrules/nixos-pinenote";
        status = "Experimental, early-stage (7 commits, 25 stars)";
        note = "Original NixOS porting effort from 2022";
      };
      nixosRockchip = {
        repo = "github:nabam/nixos-rockchip";
        supports = "Quartz64A/B, SoQuartz, PineTab2 (RK3566)";
        note = "Does NOT include PineNote - focused on SBCs";
      };
    };

    # nixos-hardware status
    nixosHardware = {
      status = "PineNote NOT included in NixOS/nixos-hardware";
      related = [
        "pine64/pinebook-pro (RK3399)"
        "pine64/rock64 (RK3328)"
        "pine64/rockpro64 (RK3399)"
      ];
    };

    # Build considerations
    build = {
      crossCompilation = "Recommended (aarch64 target from x86_64)";
      buildHost = "britton-desktop (configured in machines.nix)";
      postBoot = "sudo setup-waveform.sh required after first boot";
    };

    # Community resources
    community = {
      matrix = "#nixos-on-arm:nixos.org";
      wiki = "https://wiki.nixos.org/wiki/NixOS_on_ARM";
    };
  };

  # External Documentation Links
  docs = {
    pine64 = {
      full = "https://pine64.org/documentation/PineNote/_full/";
      development = "https://wiki.pine64.org/wiki/PineNote_Development";
      releases = "https://wiki.pine64.org/wiki/PineNote_Software_Releases";
      buildingKernel = "https://pine64.org/documentation/PineNote/Development/Building_kernel/";
    };
    kernel = {
      mWeigand = "https://github.com/m-weigand/linux (branch_pinenote_6-6-30)";
      smaeul = "https://github.com/smaeul/linux (rk356x-ebc-dev branch)";
      hrdl = "https://git.sr.ht/~hrdl/linux";
    };
    community = {
      dorianRudolph = "https://github.com/DorianRudolph/pinenotes (development guide)";
      pndeb = "https://github.com/PNDeb/pinenote-debian-image (Debian image)";
      postmarketos = "https://wiki.postmarketos.org/index.php?title=PINE64_PineNote_(pine64-pinenote)";
    };
    nixos = {
      pinenoteNixos = "https://github.com/WeraPea/pinenote-nixos";
      nixosOnArm = "https://wiki.nixos.org/wiki/NixOS_on_ARM";
      nixosHardware = "https://github.com/NixOS/nixos-hardware";
    };
  };
}
