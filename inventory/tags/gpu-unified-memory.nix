# Unified-memory (GTT) sizing for APU inference hosts.
#
# On an APU the GPU shares system memory. Two module parameters decide how much
# of that memory the GPU may map: `amdgpu.gttsize` sets the GTT aperture and
# `ttm.pages_limit` caps how many 4 KiB pages TTM hands to the GPU. Both follow
# installed memory, so the tag sizes them from a per-host memory entry and fails
# closed for a host that has no entry.
#
# The hardware inventory in machines/<host>/facter.json reports one populated
# memory device per host, so it does not carry the installed total. Each entry
# below states the installed total, and `MemTotal` on the host confirms it.
{
  config,
  lib,
  ...
}:
let
  # Installed memory per host, in MiB.
  installedMemoryMiB = {
    aspen1 = 131072; # 128 GiB installed; MemTotal reports 125 GiB usable
    aspen2 = 65536; # 64 GiB installed; MemTotal reports 62.6 GiB usable
  };

  # Share of installed memory kept for the OS and CPU workloads. The aperture is
  # system memory that the GPU maps, so this reserve is what stops GPU
  # allocations from consuming the whole machine.
  osReserveDivisor = 4;

  pageBytes = 4096;
  bytesPerMiB = 1024 * 1024;
  pagesPerMiB = bytesPerMiB / pageBytes;

  hostname = config.networking.hostName;
  installedMiB = installedMemoryMiB.${hostname} or null;
  gttMiB = if installedMiB == null then null else installedMiB - installedMiB / osReserveDivisor;
  pagesLimit = if gttMiB == null then null else gttMiB * pagesPerMiB;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = installedMiB != null;
          message = ''
            The gpu-unified-memory tag requires the installed memory of ${hostname}.
            Add the host to installedMemoryMiB in inventory/tags/gpu-unified-memory.nix
            before assigning the tag. Take the value from `MemTotal` on the host and
            round it to the installed size.
          '';
        }
      ];
    }

    (lib.mkIf (gttMiB != null) {
      boot = {
        kernelParams = [
          "amdgpu.gttsize=${toString gttMiB}"
          "ttm.pages_limit=${toString pagesLimit}"
        ];
        # The kernel parameter also reaches the module when it loads from the
        # initramfs. The modprobe option keeps the value for later loads and
        # overrides the smaller default that the amd-gpu tag sets.
        extraModprobeConfig = lib.mkAfter ''
          options ttm pages_limit=${toString pagesLimit}
        '';
      };
    })
  ];
}
