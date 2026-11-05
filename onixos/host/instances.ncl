# Instances that only the systemd-host inventory places: the OnixOS host base and the
# typed replacements for aspen2's NixOS tag files. Values follow aspen2's running
# NixOS configuration (machines/aspen2, inventory/tags) unless a comment says otherwise.
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
        boot_loader = { kind = 'grub, esp = "/boot", timeout = 5, generations = 5 },
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
        initrd_modules = ["nvme", "ahci", "sd_mod", "virtio_pci", "virtio_blk", "ext4"],
        # tun is what tailscaled needs; NixOS's tailscale module loads it (aspen2 has it
        # loaded and /dev/net/tun present).
        kernel_modules = ["amdgpu", "atkbd", "br_netfilter", "bridge", "ctr", "kvm-amd", "loop", "lz4", "lz4_compress", "overlay", "tun", "veth", "xt_nat"],
        # NetworkManager configures enp191s0; networkd only runs the Thunderbolt bridge.
        dhcp_match = [],
        # NixOS's hosts order with nscd, resolved and nss-mdns (services.avahi.nssmdns4).
        nss_hosts = ["mymachines", "mdns4_minimal", "[NOTFOUND=return]", "resolve", "[!UNAVAIL=return]", "files", "myhostname", "dns"],
        # inventory/tags/common/shared-users.nix copies wheel users' keys to root.
        root_authorized_keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework",
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX7hNDY0L9JSSIP+NVTbDluJgJ9c/l9nzbuwCNkVxgr britton@cproof.ai",
        ],
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
        # inventory/core/machines.ncl: the LAN address on enp191s0.
        static_addresses = [{ interface = "enp191s0", addresses = ["10.10.10.2/24"] }],
      },
    },
  },

  docker = {
    service = "docker",
    roles.host.machines = ["aspen2"],
  },
}
