_: {
  networking = {
    hostName = "britton-fw";
    networkmanager.enable = true;
  };

  # disko.devices.disk.main.device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_4000GB_240243803277";

  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services = {
    xserver.xkb = {
      layout = "us";
      variant = "";
    };

    openssh.enable = true;
  };

  system.stateVersion = "24.11";

  zramSwap = {
    enable = true;
    algorithm = "lz4"; # Fast compression
    memoryPercent = 87; # ~56GB of your 64GB RAM (87% of 64GB ≈ 56GB)
    priority = 100; # Higher priority than disk swap
  };

  # AIDEV-NOTE: Kernel tuning for compilation workloads
  # - Swappiness 60: Balanced between keeping working set in RAM vs using ZRAM
  # - Dirty ratios reduced: Prevent large write bursts that stall compilation
  # - Overcommit enabled: Allow memory-hungry compilers to allocate optimistically
  # - Page-cluster 0: Single-page reads optimal for ZRAM (no sequential benefit)
  # Kernel parameters for compilation workloads
  boot.kernel.sysctl = {
    "vm.swappiness" = 60; # Balanced swapping
    "vm.dirty_ratio" = 15; # Reduce dirty pages
    "vm.dirty_background_ratio" = 5; # Earlier writeback
    "vm.overcommit_memory" = 1; # Allow overcommit for compilation
    "vm.page-cluster" = 0; # Optimize for ZRAM
  };
}
