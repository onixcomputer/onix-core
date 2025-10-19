_: {
  networking = {
    hostName = "leviathan";
  };

  time.timeZone = "America/New_York";

  # Transparent Huge Pages configuration for ZGC
  boot.kernelParams = [ "transparent_hugepage=madvise" ];
  systemd.tmpfiles.rules = [
    "w /sys/kernel/mm/transparent_hugepage/shmem_enabled - - - - advise"
    "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer"
    "w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 1"
  ];

  # Nix build server configuration for 256 logical core EPYC system
  nix.settings = {
    # Prevent auto (256) which would cause massive overselling
    max-jobs = 12; # Max parallel derivations locally
    cores = 16; # Cores per derivation (16 * 12 = 192 cores max, 75% utilization)

    # Trust remote builders and use substitutes
    trusted-users = [
      "root"
      "@wheel"
      "alex"
      "brittonr"
      "dima"
      "fmzakari"
    ];
  };
}
