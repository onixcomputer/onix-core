# Default sysctl tuning for workstations with 32GB+ RAM running
# compilation-heavy workloads (Nix builds, Rust, kernel builds).
let lib = import "sysctl-lib.ncl" in
{
  # Balanced swappiness — keep working set in RAM without wasting swap entirely.
  "vm.swappiness" = 60,

  # Tighter dirty ratios prevent large write bursts that stall compilation.
  "vm.dirty_ratio" = 15,
  "vm.dirty_background_ratio" = 5,

  # Overcommit: let memory-hungry compilers allocate optimistically.
  "vm.overcommit_memory" = 1,

  # Single-page reads — no sequential benefit on ZRAM-compressed RAM.
  "vm.page-cluster" = 0,

  # Keep VFS dentries/inodes cached longer.  Big win for stat-heavy
  # workloads like nix builds and ccache lookups.
  "vm.vfs_cache_pressure" = 50,

  # Prevent allocation stalls on machines with 32GB+ under pressure.
  "vm.min_free_kbytes" = lib.kb_from_mb 64,
}
