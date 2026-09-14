# Unified-memory (GTT) sizing for APU inference hosts.
#
# On an APU the GPU shares system memory. Two module parameters decide how much
# of that memory the GPU may map: `amdgpu.gttsize` sets the GTT aperture and
# `ttm.pages_limit` caps how many 4 KiB pages TTM hands to the GPU. Both follow
# installed memory, so the sizes are per host and the tag fails closed for a host
# that has no size.
{
  config,
  lib,
  ...
}:
let
  # GTT aperture in MiB. Size each entry from installed memory: the aperture is
  # system memory that the GPU maps, so leave room for the OS and the CPU
  # workloads. The values below are the ones the inference workloads were sized
  # against.
  gttSizeMiB = {
    aspen1 = 126976;
    aspen2 = 126976;
  };

  pageBytes = 4096;
  bytesPerMiB = 1024 * 1024;
  pagesPerMiB = bytesPerMiB / pageBytes;

  hostname = config.networking.hostName;
  gttMiB = gttSizeMiB.${hostname} or null;
  pagesLimit = gttMiB * pagesPerMiB;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = gttMiB != null;
          message = ''
            The gpu-unified-memory tag requires a GTT size for ${hostname}.
            Add the host to gttSizeMiB in inventory/tags/gpu-unified-memory.nix before
            assigning the tag. Size it from installed memory, because the aperture is
            system memory that the GPU maps.
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
