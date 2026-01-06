{ lib, ... }:
{
  # SSD TRIM - maintains performance over time (weekly schedule by default)
  services.fstrim.enable = lib.mkDefault true;

  # Compressed RAM swap - reduces SSD swap wear, faster than disk
  # lz4 for speed (compilation workloads), zstd for compression ratio
  zramSwap = {
    enable = lib.mkDefault true;
    algorithm = lib.mkDefault "lz4";
    memoryPercent = lib.mkDefault 87; # Use most of RAM for ZRAM
    priority = lib.mkDefault 100; # Higher priority than disk swap
  };
}
