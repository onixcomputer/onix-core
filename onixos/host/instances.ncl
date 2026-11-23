# Instances that only the systemd-host inventory places: the OnixOS host base and the
# typed replacements for aspen2's NixOS tag files. Values follow aspen2's running
# NixOS configuration (machines/aspen2, inventory/tags) unless a comment says otherwise.
let host_root_keys = [
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework",
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX7hNDY0L9JSSIP+NVTbDluJgJ9c/l9nzbuwCNkVxgr britton@cproof.ai",
]
in
{
  host-base = {
    service = "onixos-host-base",
    roles.host = {
      machines = ["aspen2"],
      settings = {
        hostname = "aspen2",
        domain = "clan",
        timezone = "America/New_York",
        # machines/aspen2/disko.nix: GPT partitions named disk-main-aspen2-{boot,ESP,root}.
        root_device = "/dev/disk/by-partlabel/disk-main-aspen2-root",
        root_fs_type = "ext4",
        filesystems = [
          {
            device = "/dev/disk/by-partlabel/disk-main-aspen2-ESP",
            mount_point = "/boot",
            fs_type = "vfat",
            options = "umask=0077",
          },
        ],
        # GRUB stays: NixOS installed it for BIOS and removable EFI; OnixOS writes its
        # entries and keeps the NixOS grub.cfg behind a submenu.
        # The ESP is 500 MiB with 338 MiB free and NixOS's own kernel lives there; one
        # OnixOS generation is 67 MiB (52.6 initrd + 14.6 kernel), so five would leave
        # no margin and a fill would break NixOS's boot entry too. Two covers the
        # cutover generation and its rollback target.
        # A new generation is a one-shot GRUB trial. A peer acknowledges it
        # only after real, host-key-pinned LAN and Tailscale SSH checks.
        boot_loader = {
          kind = 'grub,
          esp = "/boot",
          timeout = 5,
          generations = 2,
          commit = { enable = true, remote_ack = true, timeout = 300, interval = 5 },
        },
        # linuxPackages_latest at nixpkgs 5adc508 (the kernel NixOS boots).
        kernel_version = "7.3.0",
        # nixos-hardware's framework-desktop module: redistributable firmware and
        # AMD microcode, which the GPU needs.
        firmware = 'amd,
        console = ["ttyS0,115200", "tty0"],
        kernel_params = [
          "zswap.enabled=1",
          "amdgpu.gttsize=49152",
          "ttm.pages_limit=12582912",
          "amd_pstate=active",
          "lsm=landlock,yama,apparmor,bpf",
          "apparmor=1",
          "loglevel=4",
        ],
        # r8169's realtek PHY pre-dependency is a softdep, not in modules.dep.
        # Load it explicitly before the initrd-ssh role appends r8169.
        initrd_modules = ["nvme", "ahci", "sd_mod", "virtio_pci", "virtio_blk", "ext4", "realtek"],
        # tun is what tailscaled needs; NixOS's tailscale module loads it (aspen2 has it
        # loaded and /dev/net/tun present).
        kernel_modules = ["amdgpu", "atkbd", "br_netfilter", "bridge", "ctr", "kvm-amd", "loop", "lz4", "lz4_compress", "overlay", "tun", "veth", "xt_nat"],
        # aspen2's LAN is DHCP on enp191s0; the Thunderbolt link keeps its
        # networkd bridge. NixOS's NetworkManager owns enp191s0, but the OnixOS
        # host has no NetworkManager, so networkd must run the DHCP client.
        dhcp_match = ["enp191s0"],
        # NixOS's hosts order with nscd, resolved and nss-mdns (services.avahi.nssmdns4).
        nss_hosts = ["mymachines", "mdns4_minimal", "[NOTFOUND=return]", "resolve", "[!UNAVAIL=return]", "files", "myhostname", "dns"],
        # inventory/tags/common/shared-users.nix copies wheel users' keys to root.
        root_authorized_keys = host_root_keys,
      },
    },
  },

  host-common = {
    service = "host-common",
    roles.host = {
      machines = ["aspen2"],
      # inventory/tags/thunderbolt-link.nix leaves the Thunderbolt link to networkd.
      settings.networkmanager_unmanaged = ["driver:thunderbolt-net", "interface-name:br-tbt"],
    },
  },

  host-extra = {
    service = "host-extra",
    roles.host = {
      machines = ["aspen2"],
      settings = {
        # inventory/tags/perf-tuning.nix and machines/aspen2/configuration.nix.
        scx_scheduler = "scx_bpfland",
        # The LAN is DHCP via networkd (host-base dhcp_match); 10.10.10.2/28
        # belongs only to the Thunderbolt bridge rendered by thunderbolt-link.
        static_addresses = [],
      },
    },
  },

  docker = {
    service = "docker",
    roles.host.machines = ["aspen2"],
  },

  zram = {
    service = "zram",
    roles.host.machines = ["aspen2"],
  },

  thunderbolt-link = {
    service = "thunderbolt-link",
    roles.host.machines = ["aspen2"],
  },

  amd-gpu-exporter = {
    service = "amd-gpu-exporter",
    roles.host.machines = ["aspen2"],
  },

  amd-gpu-runtime = {
    service = "amd-gpu-runtime",
    roles.host.machines = ["aspen2"],
  },

  host-policy = {
    service = "host-policy",
    roles.host = {
      machines = ["aspen2"],
      # machines/aspen2/facter.json: physical RAM, not the replica VM size.
      settings.ram_gb = 64,
    },
  },

  host-tools = {
    service = "host-tools",
    roles.host.machines = ["aspen2"],
  },

  network-extras = {
    service = "network-extras",
    roles.host.machines = ["aspen2"],
  },

  initrd-ssh = {
    service = "initrd-ssh",
    roles.host = {
      machines = ["aspen2"],
      settings = {
        port = 2222,
        interface = "enp191s0",
        driver_module = "r8169",
        authorized_keys = host_root_keys,
      },
    },
  },

  fhs-compat = {
    service = "fhs-compat",
    roles.host.machines = ["aspen2"],
  },

  vllm-cluster-network = {
    service = "vllm-cluster-network",
    roles.host.machines = ["aspen2"],
  },
}
