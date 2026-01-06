{ lib, ... }:
{
  # SSD TRIM - maintains performance over time (weekly schedule by default)
  services.fstrim.enable = true;

  # Compressed RAM swap - reduces SSD swap wear, faster than disk
  zramSwap = {
    enable = lib.mkDefault true;
    algorithm = lib.mkDefault "zstd";
  };
}
