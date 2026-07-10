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
  hostSystem = pkgs.stdenv.hostPlatform.system;
  tenstorrentPackages = inputs.tenstorrent-nix.packages.${hostSystem};
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

  environment = {
    etc."tenstorrent/README.md".text = ''
      # Tenstorrent host integration

      This host follows the Tenstorrent install docs in declarative NixOS form.

      - Driver: official `tenstorrent/tt-kmd` flake, built against `boot.kernelPackages`.
      - Device rules: installed from the KMD package via `services.udev.packages`.
      - Hugepages: `tenstorrent-hugepages.service` allocates 1GiB pages by NUMA node.
      - Hugepages mount: `${hugepagesMountPoint}` is hugetlbfs with 1GiB pages.
      - Firmware bundle: `${tenstorrentSystemFirmware}/share/tenstorrent/firmware/${firmwareBundleName}`.

      Verification after rebuild and reboot:

      ```sh
      lspci -d ${tenstorrentVendorId}:
      tt-smi -ls
      systemctl status tenstorrent-hugepages.service 'dev-hugepages\x2d1G.mount'
      ```

      Firmware flashing remains a manual operation. To flash the packaged bundle, review
      Tenstorrent's firmware instructions first, then run:

      ```sh
      sudo tt-flash --fw-tar ${tenstorrentSystemFirmware}/share/tenstorrent/firmware/${firmwareBundleName}
      ```

      If BIOS settings are reset, Tenstorrent documents that PCIe AER Reporting
      Mechanism should be set to `OS First` for TT-SMI compatibility.

      ## Software stack entry points

      This NixOS tag handles the system bringup layer: KMD, device rules,
      hugepages, firmware bundle packaging, and bringup/diagnostic tools. After
      hardware verification, choose the application/compiler layer from
      Tenstorrent's software overview: ${softwareOverviewUrl}

      ${tenstorrentSoftwareEntryPointMarkdown}
    '';

    systemPackages = selectTenstorrentTools tenstorrentPackages ++ [
      pkgs.pciutils
      tenstorrentSystemFirmware
    ];
  };
}
