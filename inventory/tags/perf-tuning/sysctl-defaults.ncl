# Sysctl tuning parameterized by machine hardware.
#
# Args (from Nix via evalNickelFileWith):
#   ramGB : Number — physical RAM in GiB
let lib = import "sysctl-lib.ncl" in

fun { ramGB, .. } =>
  {
    # Scale swappiness: small-RAM machines swap more aggressively to avoid OOM,
    # large-RAM machines keep working set resident.
    "vm.swappiness" = if ramGB < 16 then 80 else 60,

    # Tighter dirty ratios prevent large write bursts that stall compilation.
    # Machines with 64GB+ can afford slightly looser ratios.
    "vm.dirty_ratio" = if ramGB > 64 then 20 else 15,
    "vm.dirty_background_ratio" = if ramGB > 64 then 8 else 5,

    # Overcommit: let memory-hungry compilers allocate optimistically.
    "vm.overcommit_memory" = 1,

    # Single-page reads — no sequential benefit on ZRAM-compressed RAM.
    "vm.page-cluster" = 0,

    # Keep VFS dentries/inodes cached longer. Big win for stat-heavy
    # workloads like nix builds and ccache lookups.
    "vm.vfs_cache_pressure" = 50,

    # Scale min_free_kbytes with RAM to prevent allocation stalls under pressure.
    "vm.min_free_kbytes" =
      if ramGB >= 128 then
        lib.kb_from_mb 256
      else if ramGB >= 64 then
        lib.kb_from_mb 128
      else
        lib.kb_from_mb 64,
  }
