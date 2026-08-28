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

  # r[impl onix.radicle_replica.personal_persistence]
  # r[impl onix.radicle_replica.personal_listener]
  personalRadicleUserName = "brittonr";
  personalRadicleUserUid = config.users.users.${personalRadicleUserName}.uid;
  personalRadicleUserSliceName = "user-${toString personalRadicleUserUid}";
  managedRadicleNodePort = config.services.radicle.node.listenPort;
  managedRadicleNodeBindRule = "tcp:${toString managedRadicleNodePort}";
  privateSeaglassRid = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
  privateSeaglassStorageName = lib.removePrefix "rad:" privateSeaglassRid;
  privateSeaglassRevision = "44ed329b09e472aa12866c8dceedbfb3526b25a1";
  privateSeaglassIdentityRevision = "34622578746c320714509e309233fc7df051d202";
  personalRadicleHome = "/home/${personalRadicleUserName}/.radicle";
  personalRadicleNodeId = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  managedRadicleHome = "/var/lib/radicle";
  seaglassReplicationServiceName = "radicle-seaglass-replicate";
  seaglassReplicationAttempts = 24;
  seaglassReplicationRetryDelay = 5;
  seaglassReplicationConnectTimeout = "30s";
  seaglassReplicationFetchTimeout = "2min";
  seaglassReplicationCommand = pkgs.writeShellApplication {
    name = "radicle-seaglass-replicate";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gitMinimal
      pkgs.gnused
      pkgs.radicle-node
    ];
    text = ''
      attempt=1
      personal_address=""
      while [ "$attempt" -le ${toString seaglassReplicationAttempts} ]; do
        node_status="$(
          RAD_HOME=${lib.escapeShellArg personalRadicleHome} \
          RAD_SOCKET=${lib.escapeShellArg "${personalRadicleHome}/node/control.sock"} \
          rad node status 2>/dev/null || true
        )"
        personal_address="$(
          printf '%s\n' "$node_status" \
            | sed -nE 's/.*listening for inbound connections on ([^ ]+)\.$/\1/p' \
            | tail -n 1
        )"
        if [ -n "$personal_address" ]; then
          break
        fi
        sleep ${toString seaglassReplicationRetryDelay}
        attempt=$((attempt + 1))
      done

      if [ -z "$personal_address" ]; then
        echo "personal Radicle node address did not become available" >&2
        exit 1
      fi

      RAD_HOME=${lib.escapeShellArg managedRadicleHome} \
        rad node connect \
          --timeout ${lib.escapeShellArg seaglassReplicationConnectTimeout} \
          ${lib.escapeShellArg personalRadicleNodeId}@"$personal_address"

      RAD_HOME=${lib.escapeShellArg managedRadicleHome} \
        rad seed \
          --scope all \
          --from ${lib.escapeShellArg personalRadicleNodeId} \
          --timeout ${lib.escapeShellArg seaglassReplicationFetchTimeout} \
          ${lib.escapeShellArg privateSeaglassRid}

      repository_path=${lib.escapeShellArg "${managedRadicleHome}/storage/${privateSeaglassStorageName}"}
      test -d "$repository_path"
      git --git-dir="$repository_path" cat-file -e ${lib.escapeShellArg "${privateSeaglassRevision}^{commit}"}
      observed_identity="$(git --git-dir="$repository_path" rev-parse refs/rad/id)"
      test "$observed_identity" = ${lib.escapeShellArg privateSeaglassIdentityRevision}
      echo "replicated the reviewed Seaglass revision into managed Radicle storage"
    '';
  };
  kilnMaxRunTime = "2h";
  kilnExecutablePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gitMinimal
  ];
  kilnNixArgumentCount = 4;
  kilnArtifactSource = inputs.cairn.inputs.artifact;
  kilnNixCommand = pkgs.writeShellApplication {
    name = "seaglass-kiln-nix";
    text = ''
      expected_argument_count=${toString kilnNixArgumentCount}
      if [ "$#" -ne "$expected_argument_count" ]; then
        echo "expected the fixed Kiln Nix argument contract" >&2
        exit 1
      fi
      if [ "$1" != "flake" ] || [ "$2" != "check" ] || [ "$3" != "--no-update-lock-file" ]; then
        echo "refusing an unexpected Kiln Nix command" >&2
        exit 1
      fi

      exec ${pkgs.nix}/bin/nix flake check --no-update-lock-file \
        --override-input cairn/artifact path:${kilnArtifactSource} \
        "$4"
    '';
  };
  kilnConcurrentAdapters = 1;
  bytesPerMebibyte = 1024 * 1024;
  kilnMaxOutputMebibytes = 8;
  kilnMaxOutputBytes = kilnMaxOutputMebibytes * bytesPerMebibyte;
  kilnMemoryMax = "24G";
  kilnCpuQuota = "800%";
  kilnReportDirectory = "/var/lib/radicle-ci/reports";
  kilnReportHostname = "ci.onix.computer";
  kilnReportUrlPrefix = "/reports";
  kilnReportBaseUrl = "https://${kilnReportHostname}${kilnReportUrlPrefix}";
  kilnReportServerName = "radicle-ci-reports";
  kilnReportServerBindAddress = "127.0.0.1";
  kilnReportServerPort = 8990;
  kilnReportServerUser = "radicle";
  kilnReportServerGroup = "radicle";
  kilnReportServerRestartDelay = "5s";
  kilnReportServerMemoryMax = "256M";
  kilnReportServerCpuQuota = "100%";
  kilnReportTailnetSourceRange = "100.64.0.0/10";
  kilnReportStripPrefixMiddleware = "${kilnReportServerName}-strip-prefix";
  kilnReportTailnetMiddleware = "${kilnReportServerName}-tailnet-only";
  kilnReportRouterRule = "Host(`${kilnReportHostname}`) && (Path(`${kilnReportUrlPrefix}`) || PathPrefix(`${kilnReportUrlPrefix}/`))";
  kilnReportBackendUrl = "http://${kilnReportServerBindAddress}:${toString kilnReportServerPort}";

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
  vibeThinkerUnitName = "${vibeThinkerServiceName}.service";
  p150LlamaServiceName = "docker-tt-inference-server-llama-3-1-8b-instruct-p150";
  p150LlamaUnitName = "${p150LlamaServiceName}.service";
  qwenServiceName = "qwen38-p150x2";
  qwenUnitName = "${qwenServiceName}.service";
  qwenModelRevision = "1d4bf0f2ff6012fd82039f2fa52739d0dd7c60c0";
  qwenModelPath = "/home/brittonr/models/${qwenModelRevision}";
  qwenListenAddress = "127.0.0.1";
  qwenApiPort = 8000;
  qwenMaximumSequenceLength = 2048;
  qwenMaximumGenerationTokens = 64;
  qwenConflictingUnits = [
    vibeThinkerUnitName
    p150LlamaUnitName
  ];
  ttWkv7DiagnosticDevicePath = "/dev/tenstorrent/1";
  ttWkv7OwnerControlUser = "brittonr";
  ttWkv7OwnerControlCommandName = "ttwkv7-owner-control";
  ttWkv7OwnerControlSystemctl = "${config.systemd.package}/bin/systemctl";
  ttWkv7OwnerControlLsof = "${pkgs.lsof}/bin/lsof";
  ttWkv7OwnerControlSudoCommands = [
    {
      command = "${ttWkv7OwnerControlSystemctl} stop ${qwenUnitName}";
      options = [ "NOPASSWD" ];
    }
    {
      command = "${ttWkv7OwnerControlSystemctl} start ${qwenUnitName}";
      options = [ "NOPASSWD" ];
    }
    {
      command = "${ttWkv7OwnerControlLsof} ${ttWkv7DiagnosticDevicePath}";
      options = [ "NOPASSWD" ];
    }
  ];
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
  ttBenchmarkQwenRestoreMarker = "/run/${ttBenchmarkServiceName}-restore-qwen";
  ttBenchmarkSuccessMarker = "/run/${ttBenchmarkServiceName}-last-run-succeeded";
  ttBenchmarkInspectorPort = 50061;
  ttBenchmarkStateDirectoryMode = "0755";
  ttBenchmarkCore = tenstorrentPackages.tt-vibethinker-bench;
  ttBenchmarkOrchestrator = pkgs.writeShellApplication {
    name = "tt-vibethinker-benchmark-orchestrator";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      restore_qwen() {
        if test -f ${lib.escapeShellArg ttBenchmarkQwenRestoreMarker}; then
          echo "Restoring ${qwenUnitName}"
          systemctl start ${lib.escapeShellArg qwenUnitName}
          rm -f ${lib.escapeShellArg ttBenchmarkQwenRestoreMarker}
        fi
      }

      trap restore_qwen EXIT HUP INT TERM
      rm -f ${lib.escapeShellArg ttBenchmarkSuccessMarker}

      if test -f ${lib.escapeShellArg ttBenchmarkQwenRestoreMarker}; then
        echo "Recovering Qwen from an interrupted earlier benchmark"
        restore_qwen
      fi

      if systemctl is-active --quiet ${lib.escapeShellArg qwenUnitName}; then
        touch ${lib.escapeShellArg ttBenchmarkQwenRestoreMarker}
        systemctl stop ${lib.escapeShellArg qwenUnitName}
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
  ttWkv7OwnerControl = tenstorrentPackages.ttwkv7-owner-control.override {
    ownerUnit = qwenUnitName;
    devicePath = ttWkv7DiagnosticDevicePath;
  };
  # r[impl onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation]
  rwkv7P150x2Runtime = tenstorrentPackages.rwkv7-p150x2-runtime;
  rwkv7P150x2Evidence = tenstorrentPackages.rwkv7-p150x2-evidence;
in
{
  imports = [
    ./build-storage.nix
    inputs.tenstorrent-nix.nixosModules.default
  ];

  hardware = {
    # r[impl onix.tenstorrent.p150x2_qwen.deployment]
    # r[impl onix.tenstorrent.p150x2_qwen.contract]
    # r[impl onix.tenstorrent.p150x2_qwen.exclusivity]
    tenstorrent = {
      enable = true;
      driverPackage = config.boot.kernelPackages.tt-kmd;
      descriptorPackage = ttMetalPackage;
      accessPolicy = "permissive";
      meshName = "p150_x2";
      qwen38 = {
        enable = true;
        package = tenstorrentPackages.qwen36;
        modelPath = qwenModelPath;
        modelAlias = "Qwen3.8-27B";
        listenAddress = qwenListenAddress;
        port = qwenApiPort;
        maximumSequenceLength = qwenMaximumSequenceLength;
        maximumGenerationTokens = qwenMaximumGenerationTokens;
        conflictingUnits = qwenConflictingUnits;
      };
    };

    # AMD 9950X3D: microcode updates + P-State active mode.
    # Active mode lets firmware rank cores across the asymmetric CCDs.
    cpu.amd.updateMicrocode = true;

    bluetooth.settings.General = {
      Experimental = true;
      FastConnectable = true;
    };
  };

  networking = {
    hostName = "britton-desktop";
    resolvconf.extraConfig = ''
      name_servers="1.1.1.1 8.8.8.8"
    '';
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows
  services.chrony.enable = true;

  users.users.brittonr = {
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII6Mya4qU+UPAe2FUnR9L+s1Ny8MkZSA14X+aiGRJV/g id_bd"
    ];
  };

  systemd.slices.${personalRadicleUserSliceName}.sliceConfig.SocketBindDeny =
    managedRadicleNodeBindRule;

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

    # r[impl onix.radicle_ci.seaglass_kiln]
    # r[impl onix.radicle_ci.seaglass_execute]
    traefik.dynamicConfigOptions.http = {
      routers.${kilnReportServerName} = {
        rule = kilnReportRouterRule;
        service = kilnReportServerName;
        entryPoints = [ "websecure" ];
        middlewares = [
          kilnReportTailnetMiddleware
          kilnReportStripPrefixMiddleware
          "security-headers"
        ];
        tls.certResolver = "letsencrypt";
      };
      services.${kilnReportServerName}.loadBalancer.servers = [
        { url = kilnReportBackendUrl; }
      ];
      middlewares = {
        ${kilnReportTailnetMiddleware}.ipAllowList.sourceRange = [ kilnReportTailnetSourceRange ];
        ${kilnReportStripPrefixMiddleware}.stripPrefix.prefixes = [ kilnReportUrlPrefix ];
      };
    };

    radicle.ci.broker = {
      enable = true;
      settings = {
        max_run_time = kilnMaxRunTime;
        concurrent_adapters = kilnConcurrentAdapters;
        adapters.kiln = {
          command = "${
            inputs.kiln-ci-legacy.packages.${pkgs.stdenv.hostPlatform.system}.default
          }/bin/kiln-adapter-radicle";
          env = {
            KILN_ADAPTER_PROTOCOL = "defelo";
            KILN_REPORT_DIR = kilnReportDirectory;
            KILN_REPORT_BASE_URL = kilnReportBaseUrl;
            KILN_NIX = lib.getExe kilnNixCommand;
            KILN_MAX_OUTPUT_BYTES = toString kilnMaxOutputBytes;
            PATH = kilnExecutablePath;
          };
        };
        triggers = [
          {
            adapter = "kiln";
            filters = [
              {
                And = [
                  { Repository = privateSeaglassRid; }
                  { HasFile = "flake.nix"; }
                  "DefaultBranch"
                ];
              }
            ];
          }
        ];
      };
    };
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
        users = [ ttWkv7OwnerControlUser ];
        commands = [
          {
            command = "${pkgs.bpftrace}/bin/bpftrace";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/home/brittonr/.cargo-target/release/chaoscontrol-trace";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/home/brittonr/.cargo-target/release/ebpf-trace-evidence-selftest";
            options = [ "NOPASSWD" ];
          }
        ]
        ++ ttWkv7OwnerControlSudoCommands;
      }
    ];
  };

  systemd = {
    services = {
      radicle-ci-broker.serviceConfig = {
        MemoryMax = kilnMemoryMax;
        CPUQuota = kilnCpuQuota;
      };

      ${kilnReportServerName} = {
        description = "Serve private Radicle CI reports through the local Traefik backend";
        after = [ "radicle-ci-broker.service" ];
        requires = [ "radicle-ci-broker.service" ];
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = kilnReportDirectory;
        serviceConfig = {
          ExecStart = ''
            ${lib.getExe pkgs.static-web-server} \
              --host ${kilnReportServerBindAddress} \
              --port ${toString kilnReportServerPort} \
              --root ${kilnReportDirectory} \
              --log-level info \
              --directory-listing false \
              --disable-symlinks true \
              --ignore-hidden-files true
          '';
          User = kilnReportServerUser;
          Group = kilnReportServerGroup;
          WorkingDirectory = kilnReportDirectory;
          Restart = "on-failure";
          RestartSec = kilnReportServerRestartDelay;
          MemoryMax = kilnReportServerMemoryMax;
          CPUQuota = kilnReportServerCpuQuota;
          AmbientCapabilities = "";
          CapabilityBoundingSet = "";
          IPAddressAllow = [ "localhost" ];
          IPAddressDeny = [ "any" ];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          ReadOnlyPaths = [ kilnReportDirectory ];
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };

      ${seaglassReplicationServiceName} = {
        description = "Replicate private Seaglass source into managed Radicle storage";
        after = [
          "home-manager-${personalRadicleUserName}.service"
          "network-online.target"
          "radicle-node.service"
        ];
        wants = [
          "home-manager-${personalRadicleUserName}.service"
          "network-online.target"
        ];
        requires = [ "radicle-node.service" ];
        wantedBy = [ "multi-user.target" ];
        restartTriggers = [ seaglassReplicationCommand ];
        unitConfig.RequiresMountsFor = managedRadicleHome;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe seaglassReplicationCommand;
          RemainAfterExit = true;
          User = "root";
          Group = "root";
          WorkingDirectory = managedRadicleHome;
          BindReadOnlyPaths =
            config.systemd.services.radicle-policy-reconcile.serviceConfig.BindReadOnlyPaths;
          ReadWritePaths = [ managedRadicleHome ];
          AmbientCapabilities = [
            "CAP_DAC_OVERRIDE"
            "CAP_DAC_READ_SEARCH"
          ];
          CapabilityBoundingSet = [
            "CAP_DAC_OVERRIDE"
            "CAP_DAC_READ_SEARCH"
          ];
          InaccessiblePaths = [ "/run/secrets" ];
          LockPersonality = true;
          NoNewPrivileges = true;
          PrivateDevices = true;
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = "read-only";
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectSystem = "strict";
          RemoveIPC = true;
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SocketBindDeny = "any";
          SystemCallArchitectures = "native";
          UMask = "0077";
        };
      };

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

  environment.etc."tenstorrent/README.md".text = lib.mkAfter ''

    ### Declarative Qwen3.8-27B P150x2 service

    `${qwenUnitName}` is the only managed service that owns both P150 devices.
    It serves the pinned `${qwenModelRevision}` snapshot through the serialized,
    greedy OpenAI-compatible endpoint at
    `http://${qwenListenAddress}:${toString qwenApiPort}`. Prompt plus generation
    is limited to ${toString qwenMaximumSequenceLength} tokens. One request can
    generate at most ${toString qwenMaximumGenerationTokens} tokens.

    The retired `${vibeThinkerUnitName}` and `${p150LlamaUnitName}` units are
    absent from the generated host configuration. The Qwen unit also declares
    both names as conflicts to stop stale units during activation.

    Verify the deployed service with:

    ```sh
    systemctl status ${qwenUnitName}
    curl --fail http://${qwenListenAddress}:${toString qwenApiPort}/healthz
    ```

    ### britton-desktop ttWKV7 owner control

    The host installs `${ttWkv7OwnerControlCommandName}` as a least-privilege
    interface for the Qwen owner lifecycle:

    ```sh
    ${ttWkv7OwnerControlCommandName} validate
    ${ttWkv7OwnerControlCommandName} isolate
    ${ttWkv7OwnerControlCommandName} restore
    ```

    `validate` performs no service mutation. `isolate` and `restore` affect only
    `${qwenUnitName}`. Ownership inspection is fixed to
    `${ttWkv7DiagnosticDevicePath}`. This capability does not authorize a
    hardware probe, select a device, create runtime state, or permit a retry.
  '';

  environment.systemPackages = with pkgs; [
    bpftrace
    imagemagick
    nirius
    prismlauncher
    displaylink
    llamaCpuPkg
    ttBenchmarkCommand
    ttWkv7OwnerControl
    # r[verify onix.tenstorrent.native_runtime.rwkv7_p150x2.production_observation]
    rwkv7P150x2Runtime
    rwkv7P150x2Evidence
    self.packages.${pkgs.stdenv.hostPlatform.system}.opendeck
    self.packages.${pkgs.stdenv.hostPlatform.system}.ttsim
    # Keep the wrapped Herdr base on the accepted llm-agents provider.
    # r[impl onix.britton-desktop.herdr.wrapper.install]
    # r[impl onix.britton-desktop.herdr.wrapper.install.provider]
    self.packages.${pkgs.stdenv.hostPlatform.system}.herdr
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
