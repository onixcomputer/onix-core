# inventory/tags/ssd-optimization.nix's zram policy, using the same generator and
# setup unit as the pinned NixOS module. The generator owns the swap dependency
# graph; do not reset an in-use swap device during a configuration switch.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/zram",
        description = "Aspen2's lz4 compressed RAM swap for OnixOS systemd hosts.",
        categories = ["system"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS machines receive the same policy from inventory/tags/ssd-optimization.nix",
          }
        ],
      },
      packages = ["zram-generator", "util-linux-bin=util-linux.bin"],
      roles.host = {},
    },
    impl = fun args =>
      let p = args.package_paths in
      {
        output.host = {
          packages = [p."zram-generator", p."util-linux-bin"],
          package_units = [{ package = p."zram-generator", units = ["systemd-zram-setup@.service"] }],
          files = {
            "systemd/system-generators/zram-generator".source = "%{p."zram-generator"}/lib/systemd/system-generators/zram-generator",
            "systemd/zram-generator.conf".text = m%"
              [zram0]
              compression-algorithm=lz4
              swap-priority=100
              zram-size=87 / 100 * ram
            "%,
          },
          dropins."systemd-zram-setup@.service"."onixos.conf" = m%"
            [Service]
            Environment="PATH=%{p."util-linux-bin"}/bin:%{p."util-linux-bin"}/sbin"
            # As in NixOS: switch-time reset risks OOM and races with udev.
            # Real configuration changes require reboot or a safe manual restart.
            X-RestartIfChanged=false
          "%,
        },
      },
  }
  ) | onix.ServiceModule
