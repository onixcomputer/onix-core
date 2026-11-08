# Retained machine policy from the NixOS tags and systemd defaults that is not
# owned by the generic Onix host base or a service-specific module.
fun onix =>
  let sysctl_defaults = import "../../inventory/tags/perf-tuning/sysctl-defaults.ncl" in
  let host_impl = fun args =>
    let p = args.package_paths in
    let cfg = args.settings in
    let vm_sysctl = sysctl_defaults { ramGB = cfg.ram_gb } |> std.record.map (fun _key value => std.to_string value) in
    {
      output.host = {
        packages = [p."cni-plugins", p.catatonit],
        sysctl =
          vm_sysctl
          & {
            # NixOS-wide defaults from the pinned config/sysctl.nix and
            # system/boot/kernel.nix; network values already provided by
            # host-common and docker stay in those modules.
            "kernel.kptr_restrict" = "1",
            "kernel.pid_max" = "4194304",
            "kernel.printk" = "4",
            "vm.max_map_count" = "1048576",

            # Values from aspen2's generated 60-nixos.conf which are not already
            # represented by host-common or docker.
            "net.ipv4.conf.all.forwarding" = "1",
            "net.ipv4.conf.default.forwarding" = "1",
            "net.ipv4.conf.enp191s0.proxy_arp" = "0",
            "net.ipv6.conf.all.disable_ipv6" = "0",
            "net.ipv6.conf.default.disable_ipv6" = "0",
            "net.ipv6.conf.default.use_tempaddr" = "2",
            "net.ipv6.conf.enp191s0.use_tempaddr" = "2",
          },
        tmpfiles = [
          "w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise",
          "w /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise",
        ],
        kernel = {
          blacklist = ["ip_tables"],
          modprobe = [
            "options zswap enabled=1 compressor=lz4 zpool=z3fold",
            # gpu-unified-memory overrides amd-gpu's 26214400-page limit.
            "options ttm pages_limit=12582912",
          ],
        },
        files = {
          # NixOS installs the pinned systemd package's example defaults as
          # /etc/sysctl.d/50-default.conf. Preserve them before 60-onixos.conf.
          "sysctl.d/50-default.conf".text = m%"
            # This file is part of systemd.
            #
            # See sysctl.d(5) and core(5) for documentation.
            # To override settings, create a local file in /etc/sysctl.d.

            kernel.sysrq = 16
            kernel.core_uses_pid = 1

            net.ipv4.conf.default.rp_filter = 2
            net.ipv4.conf.*.rp_filter = 2
            -net.ipv4.conf.all.rp_filter

            net.ipv4.conf.default.accept_source_route = 0
            net.ipv4.conf.*.accept_source_route = 0
            -net.ipv4.conf.all.accept_source_route

            net.ipv4.conf.default.promote_secondaries = 1
            net.ipv4.conf.*.promote_secondaries = 1
            -net.ipv4.conf.all.promote_secondaries

            -net.ipv4.ping_group_range = 0 2147483647
            -net.core.default_qdisc = fq_codel

            fs.protected_hardlinks = 1
            fs.protected_symlinks = 1
            fs.protected_regular = 1
            fs.protected_fifos = 1
          "%,
          # NixOS emits these from the pinned kernel's architecture maxima.
          "sysctl.d/55-nixos-aslr-entropy.conf".text = "vm.mmap_rnd_bits=32\nvm.mmap_rnd_compat_bits=16\n",
          "modprobe.d/debian.conf".source = p."kmod-debian-aliases",
          "modprobe.d/ubuntu.conf".source = "%{p."kmod-blacklist-ubuntu"}/modprobe.conf",
          "modprobe.d/systemd.conf".text = m%"
            # SPDX-License-Identifier: LGPL-2.1-or-later
            # Avoid creating default bond0, dummy0, and ifb0 devices.
            options bonding max_bonds=0
            options dummy numdummies=0
            options ifb numifbs=0
          "%,
          "modprobe.d/firmware.conf".text = "options firmware_class path=%{p."linux-firmware"}/lib/firmware\n",
          "containers/containers.conf".text = m%"
            [engine]
            init_path = "%{p.catatonit}/bin/catatonit"

            [network]
            cni_plugin_dirs = ["%{p."cni-plugins"}/bin"]
          "%,
          "containers/storage.conf".text = m%"
            [storage]
            driver = "overlay"
            graphroot = "/var/lib/containers/storage"
            runroot = "/run/containers/storage"
          "%,
          "containers/registries.conf".text = m%"
            [[registry]]
            location = "docker.io"

            [[registry]]
            location = "quay.io"
          "%,
          "containers/policy.json".source = "%{p."skopeo-policy"}/default-policy.json",
        },
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/host-policy",
        description = "Retained NixOS system policy (sysctls, THP, modprobe, and containers configuration) for OnixOS systemd hosts.",
        categories = ["system"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS tag and systemd defaults retained for the OnixOS systemd host.",
          },
        ],
      },
      packages = [
        "cni-plugins",
        "catatonit",
        "skopeo-policy",
        "kmod-debian-aliases",
        "kmod-blacklist-ubuntu",
        "linux-firmware",
      ],
      roles.host = {
        ram_gb
          | doc "Physical RAM in GiB from machines/<host>/facter.json, passed to inventory/tags/perf-tuning/sysctl-defaults.ncl."
          | std.number.PosNat
      },
    },

    impl = host_impl,
  }
  ) | onix.ServiceModule
