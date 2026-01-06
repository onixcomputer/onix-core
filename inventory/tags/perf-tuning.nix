{ lib, ... }:
{
  # Kernel parameters optimized for compilation workloads and general responsiveness
  # - Swappiness 60: Balanced between keeping working set in RAM vs using swap
  # - Dirty ratios reduced: Prevent large write bursts that stall compilation
  # - Overcommit enabled: Allow memory-hungry compilers to allocate optimistically
  # - Page-cluster 0: Single-page reads optimal for ZRAM (no sequential benefit)
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkDefault 60;
    "vm.dirty_ratio" = lib.mkDefault 15;
    "vm.dirty_background_ratio" = lib.mkDefault 5;
    "vm.overcommit_memory" = lib.mkDefault 1;
    "vm.page-cluster" = lib.mkDefault 0;
  };
}
