# Tenstorrent Blackhole host support.
#
# Mirrors the official install docs in NixOS terms:
# - TT-KMD from the official tt-kmd flake, built against this host kernel.
# - TT-Flash, TT-SMI, TT-Topology, Luwen, and diagnostic tools from tenstorrent.nix.
# - 1GiB hugepages mount/setup matching tt-system-tools.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  packageSet = import ./packages.nix { inherit inputs lib pkgs; };
  inherit (packageSet) tenstorrentPackages;
  tenstorrentMetal = packageSet.metal;
  tenstorrentLlamaCppMetalium = packageSet.llamaCppMetalium;
  tenstorrentTtWkv7 = packageSet.ttwkv7;
  tenstorrentMetaliumRoot = packageSet.metaliumRoot;
  p150x2MeshDescriptorPath = packageSet.meshDescriptorPath;
  tenstorrentNativeRuntimeLayoutCheck = packageSet.nativeRuntimeLayoutCheck;
  tenstorrentKernelModule = config.boot.kernelPackages.tt-kmd;

  tenstorrentKernelModuleName = "tenstorrent";
  tenstorrentVendorId = "1e52";
  grayskullDeviceId = "faca";
  wormholeDeviceId = "401e";
  blackholeDeviceId = "b140";

  grayskullHugepagesPerDevice = 1;
  wormholeHugepagesPerDevice = 4;
  blackholeHugepagesPerDevice = 4;
  oneGiBHugepageKernelDir = "hugepages-1048576kB";
  hugepagesMountPoint = "/dev/hugepages-1G";
  hugepagesMountPageSize = "1G";
  hugepagesMountMode = "0777";
  hugepagesOverridePath = "/opt/tenstorrent/bin/hugepages-override.txt";
  hugepagesSetupTimeout = "10s";

  firmwareVersion = "19.11.0";
  firmwareBundleName = "fw_pack-${firmwareVersion}.fwbundle";
  firmwareBundle = pkgs.fetchurl {
    url = "https://github.com/tenstorrent/tt-system-firmware/releases/download/v${firmwareVersion}/${firmwareBundleName}";
    hash = "sha256-UAta8Nf7qGf+1EO1m8766De9keXv23P8zCAFzssYvyo=";
  };
  tenstorrentSystemFirmware = pkgs.stdenvNoCC.mkDerivation {
    pname = "tt-system-firmware";
    version = firmwareVersion;
    src = firmwareBundle;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm644 "$src" "$out/share/tenstorrent/firmware/${firmwareBundleName}"
      runHook postInstall
    '';
  };

  softwareOverviewUrl = "https://docs.tenstorrent.com/software/index.html";
  ttMetaliumToolsUrl = "https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/tools/index.html";
  ttWkv7Url = "https://github.com/marty1885/ttWKV7";
  ttWkv7CommandName = "wkv7";
  ttWkv7UpstreamTarget = "Wormhole";
  ttWkv7ManagedHostTarget = "Blackhole P150";
  ttInferenceServerUrl = "https://github.com/tenstorrent/tt-inference-server";
  ttInferenceServerPrerequisitesUrl = "https://github.com/tenstorrent/tt-inference-server/blob/main/docs/prerequisites.md";
  ttInferenceServerWorkflowsUrl = "https://github.com/tenstorrent/tt-inference-server/blob/main/docs/workflows_user_guide.md";
  ttInferenceServerHardwareModelsUrl = "https://github.com/tenstorrent/tt-inference-server/blob/main/docs/model_support/models_by_hardware.md";
  ttInferenceServerDefaultPort = 8000;
  ttInferenceServerContainerUid = 1000;
  ttInferenceServerMinimumPython = "3.8";
  ttInferenceServerSmokeTestMode = "smoke-test";

  tenstorrentSoftwareEntryPoints = [
    {
      name = "TT-Forge";
      url = "https://docs.tenstorrent.com/forge/index.html";
      useCase = "compile models from PyTorch, JAX, or ONNX; recommended first stop for most model work";
    }
    {
      name = "TT-NN";
      url = "https://docs.tenstorrent.com/tt-metal/latest/ttnn/";
      useCase = "build networks in Python from pre-optimized neural-network operations";
    }
    {
      name = "TT-Lang";
      url = "https://docs.tenstorrent.com/tt-lang/";
      useCase = "author custom fused operations in a Python DSL";
    }
    {
      name = "TT-MLIR";
      url = "https://docs.tenstorrent.com/tt-mlir/";
      useCase = "work on compiler internals or custom lowering backends";
    }
    {
      name = "TT-Metalium";
      url = "https://docs.tenstorrent.com/tt-metal/latest/tt-metalium/";
      useCase = "write kernels directly for Tensix cores when low-level control is required";
    }
    {
      name = "Cloud-Native Support";
      url = "https://docs.tenstorrent.com/cloud-native-support/";
      useCase = "install, configure, and operate Tenstorrent accelerators on Kubernetes";
    }
  ];
  mkSoftwareEntry = entry: "- [${entry.name}](${entry.url}) — ${entry.useCase}.";
  tenstorrentSoftwareEntryPointMarkdown =
    lib.concatMapStringsSep "\n" mkSoftwareEntry
      tenstorrentSoftwareEntryPoints;

  blackholeInferenceHardwareTargets = [
    {
      name = "BH LoudBox";
      url = "${ttInferenceServerHardwareModelsUrl}#bh-loudbox";
    }
    {
      name = "BH 4xP150";
      url = "${ttInferenceServerHardwareModelsUrl}#bh-4xp150";
    }
    {
      name = "BH QuietBox 2";
      url = "${ttInferenceServerHardwareModelsUrl}#bh-quietbox-2";
    }
    {
      name = "p100";
      url = "${ttInferenceServerHardwareModelsUrl}#p100";
    }
    {
      name = "p150";
      url = "${ttInferenceServerHardwareModelsUrl}#p150";
    }
  ];
  mkInferenceHardwareTarget = target: "- [${target.name}](${target.url})";
  blackholeInferenceHardwareMarkdown =
    lib.concatMapStringsSep "\n" mkInferenceHardwareTarget
      blackholeInferenceHardwareTargets;

  tenstorrentToolPackageNames = [
    "burnin"
    "flash"
    "luwen"
    "pyluwen"
    "smi"
    "system-tools"
    "topology"
  ];

  selectTenstorrentTools = packages: lib.attrVals tenstorrentToolPackageNames packages;
  ttInferenceServerWorkflowPackages = [
    pkgs.git
    pkgs.python3
    pkgs.uv
  ];

  tenstorrentHugepagesSetup = pkgs.writeShellApplication {
    name = "tenstorrent-hugepages-setup";
    runtimeInputs = [
      pkgs.gawk
      pkgs.pciutils
    ];
    text = ''
      set -euo pipefail

      tenstorrent_vendor_id="${tenstorrentVendorId}"
      grayskull_device_id="${grayskullDeviceId}"
      wormhole_device_id="${wormholeDeviceId}"
      blackhole_device_id="${blackholeDeviceId}"
      grayskull_pages_per_device="${toString grayskullHugepagesPerDevice}"
      wormhole_pages_per_device="${toString wormholeHugepagesPerDevice}"
      blackhole_pages_per_device="${toString blackholeHugepagesPerDevice}"
      hugepages_kernel_dir="${oneGiBHugepageKernelDir}"
      hugepages_override_path="${hugepagesOverridePath}"

      error_out() {
        echo "$1" >&2
        exit 1
      }

      get_node_pages() {
        local vidpid="$1"
        local pages_per_device="$2"

        lspci -d "$vidpid" -vmm \
          | awk -v pages_per_device="$pages_per_device" '
              BEGIN { numa_node = 0 }
              /NUMANode:/ { numa_node = $2 }
              /^$/ { print numa_node " " pages_per_device }
            '
      }

      declare -A nodes=()

      add_node_pages() {
        while read -r node page_count; do
          if [[ -z "''${node:-}" ]]; then
            continue
          fi

          current_count="''${nodes[$node]:-0}"
          nodes[$node]=$(( current_count + page_count ))
        done
      }

      if [[ -f "$hugepages_override_path" ]]; then
        hugepages_override="$(<"$hugepages_override_path")"
        if ! [[ "$hugepages_override" =~ ^[0-9]+$ ]]; then
          error_out "hugepages override must be an integer: $hugepages_override_path"
        fi

        tenstorrent_device_count="$(lspci -d "$tenstorrent_vendor_id:" | wc -l)"
        if (( tenstorrent_device_count == 0 )); then
          echo "No Tenstorrent devices detected by lspci -d $tenstorrent_vendor_id; skipping hugepages setup"
          exit 0
        fi

        pages_per_detected_device=$(( hugepages_override / tenstorrent_device_count ))
        echo "hugepages override requested via $hugepages_override_path: $hugepages_override"
        add_node_pages < <(
          get_node_pages "$tenstorrent_vendor_id:$blackhole_device_id" "$pages_per_detected_device"
          get_node_pages "$tenstorrent_vendor_id:$wormhole_device_id" "$pages_per_detected_device"
          get_node_pages "$tenstorrent_vendor_id:$grayskull_device_id" "$pages_per_detected_device"
        )
      else
        add_node_pages < <(
          get_node_pages "$tenstorrent_vendor_id:$blackhole_device_id" "$blackhole_pages_per_device"
          get_node_pages "$tenstorrent_vendor_id:$wormhole_device_id" "$wormhole_pages_per_device"
          get_node_pages "$tenstorrent_vendor_id:$grayskull_device_id" "$grayskull_pages_per_device"
        )
      fi

      if (( ''${#nodes[@]} == 0 )); then
        echo "No Tenstorrent devices detected by lspci -d $tenstorrent_vendor_id; skipping hugepages setup"
        exit 0
      fi

      for numa_node in "''${!nodes[@]}"; do
        node_dir="/sys/devices/system/node/node$numa_node"
        hugepage_dir="$node_dir/hugepages/$hugepages_kernel_dir"

        [[ -d "$node_dir" ]] \
          || error_out "Can't locate NUMA node directory at $node_dir. Check setup."
        [[ -d "$hugepage_dir" ]] \
          || error_out "Can't locate 1GiB hugepage settings at $hugepage_dir. Check setup."

        current_hugepages="$(<"$hugepage_dir/nr_hugepages")"
        required_hugepages="''${nodes[$numa_node]}"
        echo "Node $numa_node hugepages before: $current_hugepages"
        echo "Node $numa_node hugepages needed: $required_hugepages"
        echo "$required_hugepages" > "$hugepage_dir/nr_hugepages" \
          || error_out "Can't write to $hugepage_dir/nr_hugepages"

        configured_hugepages="$(<"$hugepage_dir/nr_hugepages")"
        echo "Node $numa_node hugepages after: $configured_hugepages"
        if [[ "$configured_hugepages" != "$required_hugepages" ]]; then
          error_out "Failed to get requested $required_hugepages hugepages, only got $configured_hugepages"
        fi
      done

      echo "Completed Tenstorrent hugepages setup"
    '';
  };
in
{
  nixpkgs.overlays = [ inputs.tt-kmd.overlays.default ];

  warnings = lib.optional (!config.virtualisation.docker.enable) ''
    The tenstorrent tag prepares TT-Inference-Server docs and workflow tools, but Docker is disabled.
    Add the docker tag or enable virtualisation.docker.enable before using tt-inference-server --docker-server workflows.
  '';

  boot = {
    extraModulePackages = [ tenstorrentKernelModule ];
    kernelModules = [ tenstorrentKernelModuleName ];
  };

  services.udev.packages = [ tenstorrentKernelModule ];

  systemd = {
    mounts = [
      {
        description = "Mount 1GiB hugepages for Tenstorrent ASICs";
        what = "hugetlbfs";
        where = hugepagesMountPoint;
        type = "hugetlbfs";
        options = "pagesize=${hugepagesMountPageSize},mode=${hugepagesMountMode},nosuid,nodev";
        before = [ "sysinit.target" ];
        wantedBy = [ "sysinit.target" ];
        unitConfig = {
          DefaultDependencies = false;
          ConditionCapability = "CAP_SYS_ADMIN";
          ConditionPathExists = "/sys/kernel/mm/hugepages/${oneGiBHugepageKernelDir}";
        };
      }
    ];

    services.tenstorrent-hugepages = {
      description = "Configure 1GiB hugepages for Tenstorrent ASICs";
      before = [ "sysinit.target" ];
      wantedBy = [ "sysinit.target" ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe tenstorrentHugepagesSetup;
        User = "root";
        Restart = "no";
        SuccessExitStatus = 0;
        TimeoutStopSec = hugepagesSetupTimeout;
      };
    };
  };

  system.extraDependencies = [ tenstorrentNativeRuntimeLayoutCheck ];

  environment = {
    variables = {
      TT_METAL_HOME = tenstorrentMetaliumRoot;
      TT_METAL_RUNTIME_ROOT = tenstorrentMetaliumRoot;
      TT_MESH_GRAPH_DESC_PATH = p150x2MeshDescriptorPath;
    };

    # r[impl onix.tenstorrent.native_runtime.firmware_boundary]
    # r[impl onix.tenstorrent.native_runtime.identity]
    etc."tenstorrent/README.md".text = ''
      # Tenstorrent host integration

      This host follows the Tenstorrent install docs in declarative NixOS form.

      - Driver: official `tenstorrent/tt-kmd` flake, built against `boot.kernelPackages`.
      - Device rules: installed from the KMD package via `services.udev.packages`.
      - Hugepages: `tenstorrent-hugepages.service` allocates 1GiB pages by NUMA node.
      - Hugepages mount: `${hugepagesMountPoint}` is hugetlbfs with 1GiB pages.
      - Firmware bundle: `${tenstorrentSystemFirmware}/share/tenstorrent/firmware/${firmwareBundleName}`.
      - Native runtime: `${tenstorrentMetal}` with TT-NN and TT-Metalium.
      - Native LLM runtime: `${tenstorrentLlamaCppMetalium}`.
      - Standalone WKV7 operator: `${tenstorrentTtWkv7}` with immutable runtime JIT kernels.
      - Linked-card topology: `${p150x2MeshDescriptorPath}` for the two p150a cards.

      Verification after rebuild and reboot:

      ```sh
      lspci -d ${tenstorrentVendorId}:
      tt-smi -ls
      systemctl status tenstorrent-hugepages.service 'dev-hugepages\x2d1G.mount'
      test -f "$TT_MESH_GRAPH_DESC_PATH"
      command -v llama-server
      ```

      Firmware flashing remains a manual operation. To flash the packaged bundle, review
      Tenstorrent's firmware instructions first, then run:

      ```sh
      sudo tt-flash --fw-tar ${tenstorrentSystemFirmware}/share/tenstorrent/firmware/${firmwareBundleName}
      ```

      If BIOS settings are reset, Tenstorrent documents that PCIe AER Reporting
      Mechanism should be set to `OS First` for TT-SMI compatibility.

      ## Native P150x2 runtime

      This host is a P150x2/DeskBox-style topology: two separate p150a cards joined
      by two QSFP-DD cables. The selected upstream descriptor declares a 1x2
      Blackhole mesh with four relaxed channels. Metalium receives that descriptor
      through `TT_MESH_GRAPH_DESC_PATH`; `TT_METAL_HOME` and
      `TT_METAL_RUNTIME_ROOT` point at the same Nix-owned SDK root.

      `p300` is not an alias for this topology. It names one dual-die P300 board.
      TT-Inference-Server does not currently publish a P150x2 model-catalog target,
      even though TT-Metal and its vLLM worker understand the `(1, 2)` P150x2 mesh.
      Use the native Metalium/TT-NN or llama.cpp Metalium path first; any P150x2
      TT-Inference-Server integration requires a separately reviewed runtime model
      specification.

      Before executing native workloads, compare the firmware reported by
      `tt-smi -s` with the selected runtime's requirements. A Nix rebuild never
      flashes firmware; use the explicit reviewed `tt-flash` command above if an
      update is required.

      ## Standalone ttWKV7 operator

      r[impl onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary]

      The `${ttWkv7CommandName}` command packages ${ttWkv7Url} against the same
      pinned TT-Metalium runtime as this host. It preserves the repository-relative
      kernel source tree required for JIT compilation. Use `${ttWkv7CommandName} test`
      for the CPU-oracle comparison and `${ttWkv7CommandName} bench` for timing.

      Upstream currently describes and benchmarks these kernels for
      **${ttWkv7UpstreamTarget}**. This host contains **${ttWkv7ManagedHostTarget}**
      accelerators. A successful Nix build proves host compilation and package
      layout only; it does not establish P150 numerical correctness or performance.
      Upstream also has no declared license at the pinned revision, so Onix
      classifies this package as unfree rather than inferring redistribution rights.

      The first bounded P150 test on 2026-07-16 confirmed that the packaged wrapper
      clears the linked-card descriptor, then stopped at upstream's Wormhole-only
      SFPU setup. The follow-up package delegates that setup to Metalium's
      architecture-selected helpers. A single follow-up run JIT-compiled all 21
      kernel artifacts and executed the chunked WKV path, but its CPU oracle failed:
      output/state PCC were 0.565670/0.512575 and normalized mean-square errors were
      1.00e+00/9.87e-01. P150 numerical compatibility is therefore disproved for
      the tested package and shape; no broader Blackhole support is claimed.

      A later exact-mask diagnostic compiled its chunked, decode, and probe math kernels
      offline for both Blackhole and Wormhole, then used an explicit writable runtime
      boundary. Its sole successful P150 process measured all seven reviewed patterns at
      lengths 1 and 32: all fourteen tiles matched their independent host predicates exactly.
      This validates the constant generators for that package and selected card only; it does
      not reclassify the deterministic full-WKV mismatch, decode correctness, performance, or
      general P150 compatibility.

      Keep edit and review iterations device-free. Build both focused gates, capture
      the composed output path, and verify that its kernel link resolves to a separate
      immutable store output without activating a NixOS generation:

      ```sh
      nix build .#checks.x86_64-linux.package-ttwkv7 --no-link
      nix build .#checks.x86_64-linux.ttwkv7-architectures --no-link
      probe_package=$(nix build .#ttwkv7 --no-link --print-out-paths)
      probe_kernel_root=$(readlink -f "$probe_package/share/ttwkv7/kernels")
      test -x "$probe_package/bin/wkv7-constant-probe"
      test -x "$probe_package/bin/wkv7-diagnose"
      test -x "$probe_package/bin/wkv7-data-movement"
      case "$probe_kernel_root" in
        /nix/store/*-ttwkv7-kernels-*/share/ttwkv7/kernels) ;;
        *) exit 1 ;;
      esac
      ```

      The next discriminator compares the pinned chunked and decodeL implementations at
      deterministic `G=1,L=1` inside one process. Before service isolation or device access,
      assign a unique reviewed run directory and non-colliding loopback port, then exercise
      the package-owned fail-closed preflight:

      ```sh
      runtime_root=/var/tmp/ttwkv7-diagnostic-REVIEWED_RUN_ID
      export TT_VISIBLE_DEVICES=1
      export TT_METAL_CACHE="$runtime_root/cache"
      export TT_METAL_LOGS_PATH="$runtime_root/logs"
      export TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=127.0.0.1:REVIEWED_PORT
      "$probe_package/bin/wkv7-diagnose" validate-runtime

      # Only after a fresh one-shot is committed, separately authorized, and the owner is isolated:
      "$probe_package/bin/wkv7-diagnose" diagnose
      ```

      The wrapper fixes the immutable target vector to `test all 1 1`; callers cannot select
      a different kernel, shape, tolerance, or suffix. The authorized comparison completed with
      nearly identical severe failures from both paths: chunked output/state PCC
      `0.565670/0.512575` and decodeL `0.565647/0.512599`, with output NMSE `1.00e+00`
      for both. That result suspects a shared boundary but does not identify one component.

      The first package-owned data-movement discriminator removed WKV compute and validated both
      tagged writer-scatter paths, but its sole process was only partial evidence: the chunked reader
      received invalid `L=1/Lreal=1` instead of fixed chunk size `L=32`, while decodeL mismatched
      exactly half of the compared elements. That package and authorization are exhausted.

      The successor self-test now validates explicit 18-field decode, chunked-partial, and
      chunked-full ABI fixtures, rejects the exhausted vector, checks CB21/input/state control
      layouts, and preserves the existing transpose, permutation, duplicate/drop, scatter, and
      sentinel negatives without a device:

      ```sh
      "$probe_package/bin/wkv7-data-movement" self-test

      data_root=/var/tmp/ttwkv7-data-movement-REVIEWED_RUN_ID
      export TT_VISIBLE_DEVICES=1
      export TT_METAL_CACHE="$data_root/cache"
      export TT_METAL_LOGS_PATH="$data_root/logs"
      export TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS=127.0.0.1:REVIEWED_PORT
      "$probe_package/bin/wkv7-data-movement" validate-runtime
      ```

      The sole successor process completed all controls and artifacts. CB21 loopback, all six
      complete input uploads, complete padded state upload, and both writer paths passed exactly.
      Decode-L1 and chunked `L=32/Lreal=1` each mismatched 71,680 elements; chunked
      `L=32/Lreal=32` mismatched 262,144. All three included the same 65,536 state mismatches.
      Pinned Blackhole requires 64-byte DRAM reads while Wormhole requires 32 bytes, and the shared
      reader face-row gathers advanced in 32-byte residues matching the odd-row/half-layout evidence.

      The packaged readers now stage Blackhole face rows through one aligned 64-byte L1 scratch
      block and locally copy the selected 32 bytes; Wormhole retains its direct asynchronous
      32-byte reads. Compile-time plans, negative source checks, and BRISC compilation validate both
      production readers for both pinned architectures without hardware. Physical confirmation still
      requires a fresh change and authorization.

      These build, self-test, and preflight commands grant no hardware authorization. Never retry
      a terminal process, never substitute a mutable profile command for the reviewed store path,
      and retain the resolved kernel path with the run evidence.

      Device execution is manual. Select one physical card, stop the service that
      owns it, run one bounded test process, review TT-Metal logs, and restore only
      the service you stopped. `TT_VISIBLE_DEVICES` maps that selected physical card
      to logical device 0, which is the unit mesh opened by upstream:

      ```sh
      physical_device_id=PHYSICAL_ID
      sequence_count=1
      token_count=1
      owner_unit=SERVICE.service

      sudo systemctl stop "$owner_unit"
      TT_VISIBLE_DEVICES="$physical_device_id" \
        ${ttWkv7CommandName} test chunked "$sequence_count" "$token_count"
      sudo systemctl start "$owner_unit"
      ```

      Do not put this command in an automatic retry loop. Upstream warns that
      repeated Metalium device create/destroy cycles can wedge a board. If the test
      fails, capture `tt-smi`, service journals, and Inspector evidence before any
      reset or architecture-support claim. The current executable is single-device;
      it does not exercise the P150x2 mesh.

      ## Debugging and profiling

      Start with the production evidence that this host keeps enabled:

      ```sh
      tt-smi -s
      journalctl -u llamacpp-server-vibethinker-britton-desktop.service
      journalctl -u llamacpp-server-supra-router.service
      find /var/lib/llamacpp-server-*/tt-metal-logs/generated/inspector -type f
      ```

      Inspector is enabled by default in TT-Metal and serializes host-runtime
      evidence under `generated/inspector`. Each Metalium service uses a private
      `TT_METAL_LOGS_PATH` and a non-colliding loopback Inspector RPC address, so
      inspect the failing service's state directory rather than the source tree.

      Official TT-Metalium debugging tools: ${ttMetaliumToolsUrl}

      Upstream only fully supports these tools on source builds. The packaged
      runtime does not install the complete `tools/tt-triage.py` workflow. For
      deeper analysis, use a TT-Metal source checkout matching the pinned runtime,
      keep Inspector enabled, and run `tt-triage` with Python 3.10 or newer.
      Enable Watcher, Device Print, debug checkpoints, NOC dumps, or profilers only
      in a focused reproduction: they instrument kernels, can alter timing or
      binary size, and are not healthy-service defaults.

      ### Managed VibeThinker benchmark matrix

      r[impl onix.tenstorrent.model_performance.managed_benchmark]

      Run the fixed device-0, device-1, and physical `1x2` comparison with:

      ```sh
      sudo tt-vibethinker-bench
      ```

      The manually invoked oneshot records whether VibeThinker and the card-1
      P150 Llama service were active, stops each owner before acquiring either
      P150, and restores only those prior active states on success, benchmark
      failure, or ordinary termination. Each benchmark case is bounded to five
      minutes. Results, TT-Metal cache entries, and Inspector logs stay outside
      the source tree. The latest
      validated result is `/var/lib/tt-vibethinker-benchmark/latest-summary.json`;
      per-run evidence remains below the same state directory.

      This diagnostic command does not enable production mesh aggregation. The
      VibeThinker service remains on its measured single-device latency path.

      ### Current llama.cpp performance profile

      r[impl onix.tenstorrent.model_performance.trace_replay]

      Metalium command-trace replay is model-specific on this host. Keep the
      checked deployment boundary instead of enabling it globally:

      - Supra-Router-51M historically enabled trace replay on physical card 1.
        Its isolated trial improved median warm decode from 88.32 to 136.15
        tokens/s (54.15%), and the bounded eager/capture passes reached 156.44
        tokens/s (77.14% over baseline). The active deployment now runs this 51M
        router on four CPU threads because it measured 1,031 tokens/s in isolation,
        preserves deterministic output, and releases card 1 for a larger model.
      - VibeThinker-3B on physical card 0 keeps trace replay disabled. The same
        trial reduced median warm decode from 22.06 to 18.13 tokens/s (17.81%).
      - Trace warmup only prepares the tested graph shape. New prompt/token shapes
        can still pay eager and capture costs before their third matching pass.
      - Firmware flashing remains outside this performance profile and is never an
        automated response to a benchmark regression.

      ### Concurrent CPU worker budget

      r[impl onix.tenstorrent.model_performance.concurrent_serving]

      VibeThinker explicitly uses eight generation and batch workers on physical
      card 0. In the historical two-Metalium deployment, the automatic 16-worker
      baseline oversubscribed the 16 physical host cores under synchronized load:
      five-run medians fell to 11.86 tokens/s for VibeThinker and 17.91 tokens/s
      for Supra. The conservative repeated eight-worker trial reached 18.51 and
      97.18 tokens/s respectively. A later supplement trial moved Supra to four
      CPU threads, preserved its output hash, measured 778 tokens/s under concurrent
      VibeThinker load, and kept VibeThinker near 19.25 tokens/s. A disjoint-CCD
      trial regressed normalized retention, so these services remain unpinned.
      Rebenchmark all active endpoints before changing either worker budget.

      ## Software stack entry points

      This NixOS tag handles the system bringup layer: KMD, device rules,
      hugepages, firmware bundle packaging, and bringup/diagnostic tools. After
      hardware verification, choose the application/compiler layer from
      Tenstorrent's software overview: ${softwareOverviewUrl}

      ${tenstorrentSoftwareEntryPointMarkdown}

      ## Serving models with TT-Inference-Server

      `tt-inference-server` is Tenstorrent's fastest path for deploying and
      testing model serving on Tenstorrent hardware: ${ttInferenceServerUrl}

      This NixOS tag prepares the host prerequisites that repository expects:
      KMD, udev rules, hugepages, firmware tooling, `tt-smi`, Docker on
      `britton-desktop`, and Python workflow tools. It intentionally does not
      vendor model-specific Docker images or mutable model weights into the Nix
      store.

      Prerequisite reference: ${ttInferenceServerPrerequisitesUrl}
      Workflow reference: ${ttInferenceServerWorkflowsUrl}
      Model support by hardware: ${ttInferenceServerHardwareModelsUrl}

      ### britton-desktop deployed serving layout

      The Tenstorrent tag owns hardware bringup, not model authority. The
      `britton-desktop` machine configuration imports the pinned `tenstorrent.nix`
      Qwen module and records its exact model, endpoint, limits, and service checks
      later in this guide. The reusable TT-Inference-Server module remains available
      for validated fixtures and future reviewed deployments, but no P150 container
      is assigned on this host while Qwen owns both devices.

      Blackhole model-support indexes to check before choosing `--model`:

      ${blackholeInferenceHardwareMarkdown}

      First-run operator workflow:

      ```sh
      cd ~/git
      git clone ${ttInferenceServerUrl}.git
      cd tt-inference-server
      # Put secrets in .env, not Nix: HF_TOKEN=... and JWT_SECRET=...
      python3 run.py --model MODEL --workflow server --docker-server --print-docker-cmd
      python3 run.py --model MODEL --workflow server --docker-server
      ```

      Notes:

      - `run.py` requires Python ${ttInferenceServerMinimumPython}+ and Docker; Podman support is documented as experimental upstream.
      - `--tt-device` can be omitted so `run.py` auto-detects hardware via `tt-smi`; set it explicitly only after checking the hardware/model support table.
      - Direct Docker runs must pass `--device /dev/tenstorrent` and mount `${hugepagesMountPoint}` into the container.
      - The default service port is `${toString ttInferenceServerDefaultPort}`.
      - Default release images run as UID `${toString ttInferenceServerContainerUid}`; host cache directories must be writable by that UID when using `--host-volume`.
      - For quick benchmark/eval validation, use `--limit-samples-mode ${ttInferenceServerSmokeTestMode}`.
    '';

    systemPackages =
      selectTenstorrentTools tenstorrentPackages
      ++ ttInferenceServerWorkflowPackages
      ++ [
        pkgs.pciutils
        tenstorrentLlamaCppMetalium
        tenstorrentMetal
        tenstorrentSystemFirmware
        tenstorrentTtWkv7
      ];
  };
}
