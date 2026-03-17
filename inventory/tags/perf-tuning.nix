{
  config,
  lib,
  self,
  wasm,
  ...
}:
let
  # Extract physical RAM from facter.json (phys_mem resource in memory devices).
  facterFile = "${self}/machines/${config.networking.hostName}/facter.json";
  facter = builtins.fromJSON (builtins.readFile facterFile);
  ramBytes =
    let
      memDevices = facter.hardware.memory or [ ];
      getPhysMem =
        dev:
        let
          physRes = builtins.filter (r: r.type or "" == "phys_mem") (dev.resources or [ ]);
        in
        if physRes == [ ] then 0 else (builtins.head physRes).range or 0;
      perDevice = map getPhysMem memDevices;
    in
    builtins.foldl' (a: b: if b > a then b else a) 0 perDevice;
  ramGB = ramBytes / (1024 * 1024 * 1024);

  sysctlDefaults = wasm.evalNickelFileWith ./perf-tuning/sysctl-defaults.ncl { inherit ramGB; };
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
