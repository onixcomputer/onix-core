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

  hostSystem = pkgs.stdenv.hostPlatform.system;
  llamaMetaliumPkg = inputs.tenstorrent-nix.packages.${hostSystem}.llama-cpp-metalium;
  supraStateDirectory = "llamacpp-server-supra-router";
  supraStateDir = "/var/lib/${supraStateDirectory}";
  supraModelsDir = "${supraStateDir}/models";
  supraModelPath = "${supraModelsDir}/supra-router-51m.gguf";
  supraCacheDir = "${supraStateDir}/cache";
  supraLogsDir = "${supraStateDir}/tt-metal-logs";
  supraPhysicalDeviceId = 1;
  supraInspectorPort = 50052;
  supraApiPort = 13306;
  supraMetaliumTrace = true;
  metaliumTraceEnabledEnvironmentValue = "1";
  metaliumTraceDisabledEnvironmentValue = "0";
  supraContextSize = 5120;
  supraGpuLayerCount = 999;
  supraBatchSize = 512;
  supraParallelSlots = 1;
  supraRestartDelaySeconds = 10;
  supraStateDirectoryMode = "0755";
  supraModelFileMode = "0644";
  supraWarmupHost = "127.0.0.1";
  supraWarmupHealthUrl = "http://${supraWarmupHost}:${toString supraApiPort}/health";
  supraWarmupCompletionUrl = "http://${supraWarmupHost}:${toString supraApiPort}/completion";
  supraWarmupPredictTokens = 64;
  supraWarmupTemperature = 0.0;
  supraWarmupSeed = 42;
  supraWarmupRequestCount = 2;
  supraWarmupFirstAttempt = 1;
  supraWarmupReadyAttempts = 30;
  supraWarmupRetryDelaySeconds = 1;
  supraWarmupRequestTimeoutSeconds = 120;
  supraWarmupExpectedFragments = [
    "| Complexity:"
    "| Route:"
  ];
  supraWarmupRequest = pkgs.writeText "supra-router-trace-warmup-request.json" (
    builtins.toJSON {
      prompt = "Task: Classify a deterministic local inference health check and select the appropriate model route.\nAnalysis:";
      n_predict = supraWarmupPredictTokens;
      temperature = supraWarmupTemperature;
      seed = supraWarmupSeed;
      cache_prompt = false;
      stream = false;
    }
  );
  supraWarmup = pkgs.writeShellApplication {
    name = "supra-router-trace-warmup";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gnugrep
    ];
    text = ''
      set -euo pipefail

      health_url=${lib.escapeShellArg supraWarmupHealthUrl}
      completion_url=${lib.escapeShellArg supraWarmupCompletionUrl}
      request_path=${lib.escapeShellArg supraWarmupRequest}
      request_count=${toString supraWarmupRequestCount}
      first_attempt=${toString supraWarmupFirstAttempt}
      max_ready_attempts=${toString supraWarmupReadyAttempts}
      retry_delay_seconds=${toString supraWarmupRetryDelaySeconds}
      request_timeout_seconds=${toString supraWarmupRequestTimeoutSeconds}

      ready=false
      attempt="$first_attempt"
      while (( attempt <= max_ready_attempts )); do
        if curl --fail --silent --output /dev/null "$health_url"; then
          ready=true
          break
        fi
        sleep "$retry_delay_seconds"
        attempt=$(( attempt + 1 ))
      done

      if [[ "$ready" != true ]]; then
        echo "Supra trace warmup skipped: readiness deadline expired" >&2
        exit 0
      fi

      response_path="$(mktemp)"
      trap 'rm -f "$response_path"' EXIT

      request_index="$first_attempt"
      while (( request_index <= request_count )); do
        if ! curl \
          --fail \
          --silent \
          --show-error \
          --max-time "$request_timeout_seconds" \
          --header 'Content-Type: application/json' \
          --data-binary "@$request_path" \
          --output "$response_path" \
          "$completion_url"; then
          echo "Supra trace warmup skipped: completion request failed" >&2
          exit 0
        fi

        for expected_fragment in ${
          lib.concatMapStringsSep " " lib.escapeShellArg supraWarmupExpectedFragments
        }; do
          if ! grep --fixed-strings --quiet "$expected_fragment" "$response_path"; then
            echo "Supra trace warmup skipped: response schema check failed" >&2
            exit 0
          fi
        done

        request_index=$(( request_index + 1 ))
      done

      echo "Supra trace warmup completed $request_count capture passes"
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
      # Supra-Router-51M — isolated to the second physical P150 card.
      llamacpp-server-supra-router = {
        description = "Metalium inference server — Supra-Router-51M";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];
        preStart = ''
          mkdir -p ${supraModelsDir} ${supraCacheDir} ${supraLogsDir}
          if [ ! -f ${supraModelPath} ] && [ -f /home/brittonr/models/supra-router-51m.gguf ]; then
            cp /home/brittonr/models/supra-router-51m.gguf ${supraModelsDir}/
            chmod ${supraModelFileMode} ${supraModelPath}
          fi
        '';
        # r[impl onix.tenstorrent.model_performance.trace_replay]
        # This bounded post-start hook runs on every service restart. Failures are
        # reported but return success so an optimization cannot restart-loop the API.
        postStart = lib.getExe supraWarmup;
        environment = {
          HOME = supraStateDir;
          GGML_METALIUM_DEVICE_ID = "0";
          # r[impl onix.tenstorrent.model_performance.trace_replay]
          GGML_METALIUM_TRACE =
            if supraMetaliumTrace then
              metaliumTraceEnabledEnvironmentValue
            else
              metaliumTraceDisabledEnvironmentValue;
          TT_METAL_CACHE = supraCacheDir;
          TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS = "127.0.0.1:${toString supraInspectorPort}";
          TT_METAL_LOGS_PATH = supraLogsDir;
          TT_VISIBLE_DEVICES = toString supraPhysicalDeviceId;
        };
        serviceConfig = {
          ExecStart = ''
            ${llamaMetaliumPkg}/bin/llama-server \
              --host 0.0.0.0 --port ${toString supraApiPort} \
              --model ${supraModelPath} \
              --alias Supra-Router-51M \
              --ctx-size ${toString supraContextSize} \
              --gpu-layers ${toString supraGpuLayerCount} \
              --flash-attn off \
              --no-kv-offload \
              --no-mmap \
              --metrics \
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
            "GGML_METALIUM_MESH_SHAPE"
            "TT_MESH_GRAPH_DESC_PATH"
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
    llamaMetaliumPkg
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
