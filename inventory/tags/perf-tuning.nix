{
  lib,
  pkgs,
  self,
  ...
}:
let
  plugins = pkgs.callPackage "${self}/wasm-plugins" {
    inherit (pkgs.llvmPackages) lld;
    inherit (self.inputs) nickel-wasm-vendor;
  };
  wasm = import "${self}/lib/wasm.nix" { inherit plugins; };

  # Sysctl defaults defined in Nickel — imports sysctl-lib.ncl for helpers.
  sysctlDefaults = wasm.evalNickelFile ./perf-tuning/sysctl-defaults.ncl;
in
{
  boot.kernel.sysctl = lib.mapAttrs (_: lib.mkDefault) sysctlDefaults;

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
