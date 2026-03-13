_: {
  # zswap: compressed cache for swap pages in RAM.
  # Compresses pages with lz4 before they hit disk swap, keeping more
  # working set in memory. z3fold allocator packs 3 compressed pages
  # per physical page.
  #
  # Complements zramSwap (srvos enables it via common module,
  # ssd-optimization.nix configures size/algorithm per-machine):
  # zram IS the swap device, zswap sits in front of any disk-backed
  # swap. Both can coexist — zswap catches overflow before NVMe.

  boot = {
    kernelParams = [ "zswap.enabled=1" ];
    kernelModules = [
      "lz4"
      "lz4_compress"
    ];
    extraModprobeConfig = ''
      options zswap enabled=1 compressor=lz4 zpool=z3fold
    '';
  };
}
