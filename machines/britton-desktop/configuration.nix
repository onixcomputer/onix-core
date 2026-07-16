{
  config,
  lib,
  pkgs,
  inputs,
  self,
  ...
}:
let
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

  llamaCpuPkg = pkgs.llama-cpp;
  supraStateDirectory = "llamacpp-server-supra-router";
  supraStateDir = "/var/lib/${supraStateDirectory}";
  supraModelsDir = "${supraStateDir}/models";
  supraModelPath = "${supraModelsDir}/supra-router-51m.gguf";
  supraApiPort = 13306;
  supraContextSize = 5120;
  supraGpuLayerCount = 0;
  supraWorkerThreads = 4;
  supraBatchSize = 512;
  supraParallelSlots = 1;
  supraRestartDelaySeconds = 10;
  supraStateDirectoryMode = "0755";
  supraModelFileMode = "0644";

  tenstorrentPackages = inputs.tenstorrent-nix.packages.${pkgs.stdenv.hostPlatform.system};
  ttMetaliumPackage = tenstorrentPackages.llama-cpp-metalium;
  ttMetalPackage = tenstorrentPackages.tt-metal;
  ttMetaliumRuntimeRoot = "${ttMetalPackage}/libexec/tt-metalium";
  ttP150x2MeshDescriptor = "${ttMetaliumRuntimeRoot}/tt_metal/fabric/mesh_graph_descriptors/p150_x2_mesh_graph_descriptor.textproto";
  vibeThinkerServiceName = "llamacpp-server-vibethinker-britton-desktop";
  vibeThinkerStateDirectory = vibeThinkerServiceName;
  vibeThinkerModelPath = "/var/lib/${vibeThinkerStateDirectory}/models/VibeThinker-3B.Q8_0.gguf";
  ttBenchmarkServiceName = "tt-vibethinker-benchmark";
  ttBenchmarkUnitName = "${ttBenchmarkServiceName}.service";
  ttBenchmarkStateDirectory = ttBenchmarkServiceName;
  ttBenchmarkStateDir = "/var/lib/${ttBenchmarkStateDirectory}";
  ttBenchmarkCacheDirectory = ttBenchmarkServiceName;
  ttBenchmarkCacheDir = "/var/cache/${ttBenchmarkCacheDirectory}";
  ttBenchmarkLogsDirectory = ttBenchmarkServiceName;
  ttBenchmarkLogsDir = "/var/log/${ttBenchmarkLogsDirectory}";
  ttBenchmarkLatestSummary = "${ttBenchmarkStateDir}/latest-summary.json";
  ttBenchmarkRestoreMarker = "/run/${ttBenchmarkServiceName}-restore-vibethinker";
  ttBenchmarkSuccessMarker = "/run/${ttBenchmarkServiceName}-last-run-succeeded";
  ttBenchmarkInspectorPort = 50061;
  ttBenchmarkStateDirectoryMode = "0755";
  ttBenchmarkCore = pkgs.callPackage ../../pkgs/tt-vibethinker-bench { };
  ttBenchmarkOrchestrator = pkgs.writeShellApplication {
    name = "tt-vibethinker-benchmark-orchestrator";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      restore_vibethinker() {
        if test -f ${lib.escapeShellArg ttBenchmarkRestoreMarker}; then
          echo "Restoring ${vibeThinkerServiceName}.service"
          systemctl start ${lib.escapeShellArg "${vibeThinkerServiceName}.service"}
          rm -f ${lib.escapeShellArg ttBenchmarkRestoreMarker}
        fi
      }

      trap restore_vibethinker EXIT HUP INT TERM
      rm -f ${lib.escapeShellArg ttBenchmarkSuccessMarker}

      if test -f ${lib.escapeShellArg ttBenchmarkRestoreMarker}; then
        echo "Recovering VibeThinker from an interrupted earlier benchmark"
        restore_vibethinker
      fi

      if systemctl is-active --quiet ${lib.escapeShellArg "${vibeThinkerServiceName}.service"}; then
        touch ${lib.escapeShellArg ttBenchmarkRestoreMarker}
        systemctl stop ${lib.escapeShellArg "${vibeThinkerServiceName}.service"}
      fi

      ${lib.getExe ttBenchmarkCore} \
        --llama-bench ${lib.escapeShellArg "${ttMetaliumPackage}/bin/llama-bench"} \
        --model ${lib.escapeShellArg vibeThinkerModelPath} \
        --output-root ${lib.escapeShellArg ttBenchmarkStateDir} \
        --cache-root ${lib.escapeShellArg ttBenchmarkCacheDir} \
        --logs-root ${lib.escapeShellArg ttBenchmarkLogsDir} \
        --mesh-descriptor ${lib.escapeShellArg ttP150x2MeshDescriptor} \
        --inspector-port ${toString ttBenchmarkInspectorPort}

      touch ${lib.escapeShellArg ttBenchmarkSuccessMarker}
    '';
  };
  ttBenchmarkCommand = pkgs.writeShellApplication {
    name = "tt-vibethinker-bench";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      if test "$(id -u)" -ne 0; then
        echo "Run this benchmark as root: sudo tt-vibethinker-bench" >&2
        exit 1
      fi

      rm -f ${lib.escapeShellArg ttBenchmarkSuccessMarker}
      systemctl start ${lib.escapeShellArg ttBenchmarkUnitName}
      if ! test -f ${lib.escapeShellArg ttBenchmarkSuccessMarker}; then
        echo "${ttBenchmarkServiceName} did not complete a new validated run" >&2
        exit 1
      fi
      if ! test -f ${lib.escapeShellArg ttBenchmarkLatestSummary}; then
        echo "Benchmark completed without publishing ${ttBenchmarkLatestSummary}" >&2
        exit 1
      fi
      cat ${lib.escapeShellArg ttBenchmarkLatestSummary}
    '';
  };
in
{
  networking = {
    hostName = "britton-desktop";
    resolvconf.extraConfig = ''
      name_servers="1.1.1.1 8.8.8.8"
    '';
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows

  nix.settings = {
    # Enable experimental features for uid-range support and Nix build cgroups.
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    auto-allocate-uids = true;

    # Desktop-safe local Nix budget for the Ryzen 9 9950X3D:
    # 4 concurrent derivations × 4 build cores = 16 build threads, leaving
    # half of the 32 hardware threads schedulable for the compositor, browser,
    # editor, shells, and background services. Increase only for intentional
    # batch/off-hours builds or remote-builder-only workflows.
    max-jobs = 4;
    cores = 4;
    use-cgroups = true;

    # System features for NixOS container tests
    system-features = [
      "uid-range"
      "kvm"
      "nixos-test"
      "big-parallel"
    ];
  };

  # AMD 9950X3D: microcode updates + P-State active mode.
  # active mode lets firmware handle preferred-core ranking across the
  # asymmetric CCDs (3D V-Cache vs high-clock).
  hardware.cpu.amd.updateMicrocode = true;

  hardware.bluetooth.settings.General = {
    Experimental = true;
    FastConnectable = true;
  };

  boot = {
    kernelParams = [ "amd_pstate=active" ];
    kernel.sysctl."kernel.perf_event_paranoid" = -1;
    kernelPackages = pkgs.linuxPackages_6_18;
    kernelPatches = [
      {
        name = "btusb-foxconn-mt7925-e13a";
        patch = ../../patches/linux-btusb-foxconn-mt7925-e13a.patch;
      }
    ];
    # DisplayLink support for Wayland (evdi module)
    extraModulePackages = [ config.boot.kernelPackages.evdi ];
    kernelModules = [ "evdi" ];
    loader = {
      timeout = 1;
      grub = {
        timeoutStyle = "menu";
        enable = true;
        device = "nodev";
        efiSupport = true;
        configurationLimit = 5;
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
        '';
      };
    };
  };

  services = {
    # Override greeter session for niri
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";

    # Qualcomm EDL mode access
    udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0666"
      SUBSYSTEM=="block", ENV{ID_VENDOR_ID}=="1949", ENV{ID_MODEL_ID}=="0324", TAG+="uaccess"
      # Rockchip Maskrom/Loader
      SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0660", GROUP="wheel"
      # SDWire (Realtek card reader with mux control)
      SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="0316", MODE="0660", GROUP="wheel"
      # Elgato Stream Deck (OpenDeck)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", MODE="0660", TAG+="uaccess"
    '';

    pipewire.wireplumber.extraConfig = {
      "10-bluez-airpods" = {
        "monitor.bluez.properties" = {
          "bluez5.codecs" = bluetoothAudioCodecs;
          "bluez5.dummy-avrcp-player" = true;
          "bluez5.enable-sbc-xq" = true;
          "bluez5.hfphsp-backend" = "native";
          "bluez5.roles" = bluetoothAudioRoles;
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

    printing.enable = true;
  };

  security = {
    pam.services = {
      sudo.fprintAuth = false;
    };

    # srvos sets security.sudo.execWheelOnly = true, which asserts that
    # extraRules only reference root/wheel. We need per-user rules here,
    # so disable it on this machine.
    sudo.execWheelOnly = lib.mkForce false;

    sudo.extraRules = [
      {
        users = [ "brittonr" ];
        commands = [
          {
            command = "${pkgs.bpftrace}/bin/bpftrace";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/home/brittonr/.cargo-target/release/chaoscontrol-trace";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];
  };

  systemd = {
    services = {
      # The supplementary Llama rollout must not interrupt the existing card-0
      # service even when its reproducible package path changes during activation.
      llamacpp-server-vibethinker-britton-desktop.restartIfChanged = false;

      # r[impl onix.tenstorrent.model_performance.managed_benchmark]
      ${ttBenchmarkServiceName} = {
        description = "Validated VibeThinker benchmark matrix for both P150 cards";
        serviceConfig = {
          Type = "oneshot";
          ExecCondition = "${pkgs.coreutils}/bin/test -f ${vibeThinkerModelPath}";
          ExecStart = lib.getExe ttBenchmarkOrchestrator;
          User = "root";
          Group = "root";
          StateDirectory = ttBenchmarkStateDirectory;
          StateDirectoryMode = ttBenchmarkStateDirectoryMode;
          CacheDirectory = ttBenchmarkCacheDirectory;
          LogsDirectory = ttBenchmarkLogsDirectory;
          WorkingDirectory = ttBenchmarkStateDir;
          TimeoutStartSec = "infinity";
        };
        environment = {
          HOME = ttBenchmarkStateDir;
          TT_METAL_HOME = ttMetaliumRuntimeRoot;
          TT_METAL_RUNTIME_ROOT = ttMetaliumRuntimeRoot;
          TT_MESH_GRAPH_DESC_PATH = ttP150x2MeshDescriptor;
        };
      };

      # DisplayLink Manager service
      dlm = {
        description = "DisplayLink Manager Service";
        after = [ "display-manager.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.displaylink}/bin/DisplayLinkManager";
          Restart = "always";
          RestartSec = 5;
          LogsDirectory = "displaylink";
        };
      };

      # r[impl onix.tenstorrent.concurrent_models.supra]
      # The 51M router is materially faster on CPU and leaves physical card 1
      # available for the larger vLLM service.
      llamacpp-server-supra-router = {
        description = "CPU inference server — Supra-Router-51M";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        preStart = ''
          mkdir -p ${supraModelsDir}
          if [ ! -f ${supraModelPath} ] && [ -f /home/brittonr/models/supra-router-51m.gguf ]; then
            cp /home/brittonr/models/supra-router-51m.gguf ${supraModelsDir}/
            chmod ${supraModelFileMode} ${supraModelPath}
          fi
        '';
        environment.HOME = supraStateDir;
        serviceConfig = {
          ExecStart = ''
            ${llamaCpuPkg}/bin/llama-server \
              --host 0.0.0.0 --port ${toString supraApiPort} \
              --model ${supraModelPath} \
              --alias Supra-Router-51M \
              --ctx-size ${toString supraContextSize} \
              --gpu-layers ${toString supraGpuLayerCount} \
              --no-mmap \
              --metrics \
              --threads ${toString supraWorkerThreads} \
              --threads-batch ${toString supraWorkerThreads} \
              --batch-size ${toString supraBatchSize} \
              --ubatch-size ${toString supraBatchSize} \
              --parallel ${toString supraParallelSlots} \
              --fit off \
              --temp 0.0
          '';
          Restart = "on-failure";
          RestartSec = supraRestartDelaySeconds;
          StateDirectory = supraStateDirectory;
          StateDirectoryMode = supraStateDirectoryMode;
          WorkingDirectory = supraStateDir;
          UnsetEnvironment = [
            "GGML_METALIUM_DEVICE_ID"
            "GGML_METALIUM_MESH_SHAPE"
            "GGML_METALIUM_TRACE"
            "TT_MESH_GRAPH_DESC_PATH"
            "TT_METAL_CACHE"
            "TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS"
            "TT_METAL_LOGS_PATH"
            "TT_VISIBLE_DEVICES"
          ];
          User = "root";
          Group = "root";
        };
      };

      # Keep daemon-managed builds below interactive desktop work. Nix builds are
      # also capped by nix.settings max-jobs/cores above; these cgroup weights and
      # memory pressure guard protect the compositor/session when builds are busy.
      nix-daemon.serviceConfig = {
        CPUWeight = 25;
        IOWeight = 25;
        MemoryHigh = "140G";
      };
    };

    # Prevent suspend/sleep entirely — this machine should always stay on
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  programs.fuse.userAllowOther = true;

  home-manager.users.brittonr.home.packages = with pkgs; [
    librepods
  ];

  environment.systemPackages = with pkgs; [
    bpftrace
    imagemagick
    nirius
    prismlauncher
    displaylink
    llamaCpuPkg
    ttBenchmarkCommand
    self.packages.${pkgs.stdenv.hostPlatform.system}.opendeck
    self.packages.${pkgs.stdenv.hostPlatform.system}.ttsim
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];

  # ZFS on the 4TB data drive
  networking.hostId = "07e6df3e";
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "datapool" ];

  # Put /tmp on the 4TB datapool instead of RAM-backed tmpfs, while keeping
  # classic scratch-directory semantics across boots.
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };
}
