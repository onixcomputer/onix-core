{ lib, ... }:
{
  boot.kernel.sysctl = {
    # Swappiness 60: balanced between keeping working set in RAM vs using swap
    "vm.swappiness" = lib.mkDefault 60;
    # Reduced dirty ratios: prevent large write bursts that stall compilation
    "vm.dirty_ratio" = lib.mkDefault 15;
    "vm.dirty_background_ratio" = lib.mkDefault 5;
    # Overcommit: allow memory-hungry compilers to allocate optimistically
    "vm.overcommit_memory" = lib.mkDefault 1;
    # Single-page reads optimal for ZRAM (no sequential benefit on compressed RAM)
    "vm.page-cluster" = lib.mkDefault 0;
    # Keep VFS dentries/inodes cached longer — big win for compilation and nix builds
    # (lots of stat/readdir). Default 100 evicts too aggressively.
    "vm.vfs_cache_pressure" = lib.mkDefault 50;
    # Prevent allocation stalls on 32GB+ machines under memory pressure.
    # Default is auto-calculated and often too low.
    "vm.min_free_kbytes" = lib.mkDefault 65536;
  };

  # Transparent Huge Pages: madvise instead of always.
  # Avoids latency spikes from background compaction/defrag.
  # Apps that want THP (JVM, databases) can still request it via madvise.
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
  ];

  # sched-ext: pluggable eBPF scheduler (mainline since 6.12)
  # scx_bpfland: classifies tasks by context-switch rate, interactive tasks
  # get priority queue. Fully in-BPF, no userspace in the hot path.
  # Falls back to stock EEVDF if the scheduler crashes (5s watchdog).
  services.scx = {
    enable = lib.mkDefault true;
    scheduler = lib.mkDefault "scx_bpfland";
  };
}
