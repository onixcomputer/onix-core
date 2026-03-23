# Cloud Hypervisor VM — Create & Install Guide

How to add a new cloud-hypervisor guest VM to this infrastructure. The host
runs cloud-hypervisor with direct kernel boot; the guest is a standard
NixOS machine managed through clan.

Throughout this guide, replace `chv-myvm` with your chosen machine name.

## Prerequisites

- The host machine (currently `britton-desktop`) has the `cloud-hypervisor-host` tag
- You have root access to the host for bootstrap
- The host has been deployed with the cloud-hypervisor-host tag config active

## Architecture

```
britton-desktop (host)
├── cloud-hypervisor-network.service    # br-chv bridge, 172.16.0.1/24
├── dnsmasq                             # DHCP on br-chv, per-VM reservations
└── cloud-hypervisor-chv-myvm.service   # one systemd unit per VM
    ├── TAP interface (tap-chv-myvm)    # bridged to br-chv
    ├── --kernel vmlinux                # guest kernel from nix store
    ├── --initramfs initrd              # guest initrd from nix store
    └── --disk /var/lib/cloud-hypervisor/chv-myvm.img
```

The host tag (`inventory/tags/cloud-hypervisor-host.nix`) provides the bridge,
NAT, dnsmasq, and firewall rules. The guest tag
(`inventory/tags/cloud-hypervisor-guest.nix`) configures the guest for virtio
I/O, serial console, and systemd-networkd DHCP.

The `cloud-hypervisor-vm` clan service module (`modules/cloud-hypervisor-vm/`)
generates a systemd service on the host for each guest instance.

## Step-by-step

### 1. Pick network parameters

Each VM needs a unique IP, MAC, and TAP name on the `172.16.0.0/24` bridge.

Check existing allocations in `inventory/services/services.ncl` under the
`# ========== Cloud Hypervisor VMs ==========` section:

| VM        | IP           | MAC               | TAP            |
|-----------|--------------|-------------------|----------------|
| chv-dev1  | 172.16.0.10  | 52:54:00:c0:ff:01 | tap-chv-dev1   |
| chv-dev2  | 172.16.0.11  | 52:54:00:c0:ff:02 | tap-chv-dev2   |
| chv-dev3  | 172.16.0.12  | 52:54:00:c0:ff:03 | tap-chv-dev3   |

Pick the next available values. The `52:54:00` OUI prefix is the standard
locally-administered range for VMs. The subnet is `172.16.0.2–254` (`.1` is
the host gateway, `.2` is reserved for the legacy RedoxOS TAP).

### 2. Create the machine directory

```bash
mkdir -p machines/chv-myvm
```

**`machines/chv-myvm/configuration.nix`**:

```nix
# chv-myvm — Cloud Hypervisor x86_64-linux guest on britton-desktop.
#
# Direct kernel boot, virtio I/O, deployed via `clan machines update chv-myvm`.
# Host-side networking: TAP bridge 172.16.0.0/24, DHCP from dnsmasq.
{
  pkgs,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "chv-myvm";
  time.timeZone = "America/New_York";

  # SSH — primary access and clan deploy target.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # zram swap — no physical swap partition in a lightweight VM.
  zramSwap.enable = true;

  environment.systemPackages = with pkgs; [
    btop
    git
    htop
    jq
    ripgrep
    vim
  ];

  system.stateVersion = "25.05";
}
```

**`machines/chv-myvm/disko.nix`** (identical for all CHV guests):

```nix
# Disk layout for cloud-hypervisor guest.
# Single ext4 partition on virtio-blk /dev/vda — no ESP, no bootloader.
# GPT partition table required: cloud-hypervisor disables writes to sector 0
# on raw images, so the filesystem must start at an offset (partition 1).
{
  disko.devices.disk.main = {
    device = "/dev/vda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
```

### 3. Register the machine in the Nickel inventory

Edit `inventory/core/machines.ncl`. Add the new machine under the
`# ========== Cloud Hypervisor VMs ==========` section:

```nickel
chv-myvm = {
  name = "chv-myvm",
  system = "x86_64-linux",
  tags = [
    "cloud-hypervisor-guest",
    "minimal-docs",
  ],
  deploy = {
    targetHost = "root@172.16.0.13",  # your chosen IP
    buildHost = "britton-desktop",
  },
},
```

Key fields:
- **tags**: `cloud-hypervisor-guest` applies the guest boot/network config.
  `minimal-docs` saves closure size on headless VMs.
- **deploy.targetHost**: `root@<guest-ip>` — clan deploys over SSH to this address.
- **deploy.buildHost**: builds happen on the host machine, not inside the VM.

Add extra tags as needed (`hm-server` for home-manager, `dev` for dev tools,
`tailnet-brittonr` for Tailscale, etc.).

### 4. Add the service instance

Edit `inventory/services/services.ncl`. Add an entry under the Cloud
Hypervisor VMs section:

```nickel
chv-myvm = {
  module = { name = "cloud-hypervisor-vm", input = "self" },
  roles.host.machines.britton-desktop.settings = {
    guestMachine = "chv-myvm",
    cpus = 2,
    memory = 2048,
    diskPath = "/var/lib/cloud-hypervisor/chv-myvm.img",
    tapInterface = "tap-chv-myvm",
    macAddress = "52:54:00:c0:ff:04",   # next available
    guestIp = "172.16.0.13",            # next available
  },
},
```

Settings reference:

| Field          | Description                                      |
|----------------|--------------------------------------------------|
| `guestMachine` | Must match the machine name in `machines.ncl`    |
| `cpus`         | vCPU count (also controls multi-queue I/O)       |
| `memory`       | RAM in MiB                                       |
| `diskPath`     | Where the raw disk image lives on the host       |
| `diskSize`     | Used by `bootstrap.sh` (default `40G`)           |
| `tapInterface` | TAP device name on the host                      |
| `macAddress`   | Unique MAC for DHCP reservation                  |
| `guestIp`      | Static DHCP lease from dnsmasq                   |

For multi-queue: when `cpus > 1`, the module enables multi-queue virtio-blk
(queues = cpus) and virtio-net (queues = cpus × 2).

### 5. Validate the configuration

```bash
# Enter dev shell if not already
nix develop

# Validate contracts (catches tag typos, missing fields, ref errors)
ncl export inventory/core/machines.ncl
ncl export inventory/services/services.ncl

# Build the guest system (catches Nix eval errors)
build chv-myvm

# Build the host (picks up the new systemd service + dnsmasq reservation)
build britton-desktop
```

### 6. Generate secrets

```bash
clan vars generate --machine chv-myvm
```

This generates SSH host keys and any other secrets required by the
machine's tags and services.

### 7. Deploy the host

The host needs the new systemd service and dnsmasq DHCP reservation before
the guest can boot:

```bash
clan machines update britton-desktop
```

After deploy, verify the new service exists (it will fail to start since
the disk image doesn't exist yet):

```bash
ssh britton-desktop systemctl status cloud-hypervisor-chv-myvm
```

### 8. Bootstrap the guest disk image

On the host machine:

```bash
sudo bash modules/cloud-hypervisor-vm/bootstrap.sh chv-myvm
```

This does:
1. Builds the guest NixOS toplevel
2. Creates a 40G GPT-partitioned raw disk image at `/var/lib/cloud-hypervisor/chv-myvm.img`
3. Formats with ext4
4. Runs `nixos-install` into the image
5. Generates `/etc/machine-id` (required for systemd-networkd DHCP)

To customize the disk path or size:

```bash
sudo bash modules/cloud-hypervisor-vm/bootstrap.sh chv-myvm /path/to/disk.img 80G
```

### 9. Start the VM

```bash
sudo systemctl start cloud-hypervisor-chv-myvm
```

Verify it booted and got its DHCP lease:

```bash
# Check the service
systemctl status cloud-hypervisor-chv-myvm

# Check dnsmasq leases
cat /var/lib/dnsmasq/dnsmasq.leases

# Test SSH access
ssh root@172.16.0.13
```

### 10. Deploy the guest

Now that the VM is running and reachable over SSH, deploy the full
clan-managed configuration:

```bash
clan machines update chv-myvm
```

This builds on `britton-desktop` (per `buildHost`) and pushes the closure
to the guest via SSH.

## Day-to-day operations

### Start / stop / restart

```bash
# On the host:
systemctl start   cloud-hypervisor-chv-myvm
systemctl stop    cloud-hypervisor-chv-myvm   # ACPI power button → clean shutdown
systemctl restart cloud-hypervisor-chv-myvm
```

The VM auto-starts on host boot (`wantedBy = multi-user.target`).

### Deploy config changes

```bash
clan machines update chv-myvm
```

If the change touches the kernel or initrd, restart the VM afterward —
cloud-hypervisor loads these at boot time, not from the running guest
filesystem:

```bash
sudo systemctl restart cloud-hypervisor-chv-myvm
```

### Serial console

VM serial output goes to the systemd journal:

```bash
journalctl -u cloud-hypervisor-chv-myvm -f
```

### API socket

Each VM has a REST API socket for introspection and control:

```bash
# VM info
curl --unix-socket /run/cloud-hypervisor-chv-myvm.sock http://localhost/api/v1/vm.info | jq

# ACPI power button (same as systemctl stop)
curl --unix-socket /run/cloud-hypervisor-chv-myvm.sock -X PUT http://localhost/api/v1/vm.power-button
```

### Disk resize

```bash
systemctl stop cloud-hypervisor-chv-myvm
truncate -s 80G /var/lib/cloud-hypervisor/chv-myvm.img
LOOP=$(losetup --find --show -P /var/lib/cloud-hypervisor/chv-myvm.img)
sgdisk -e $LOOP
sgdisk -d 1 -n 1:0:0 -c 1:disk-main-root -t 1:8300 $LOOP
partprobe $LOOP; sleep 1
e2fsck -f ${LOOP}p1
resize2fs ${LOOP}p1
losetup -d $LOOP
systemctl start cloud-hypervisor-chv-myvm
```

## Checklist

- [ ] Network parameters chosen (IP, MAC, TAP — no collisions)
- [ ] `machines/chv-myvm/configuration.nix` created
- [ ] `machines/chv-myvm/disko.nix` created
- [ ] Machine added to `inventory/core/machines.ncl`
- [ ] Service instance added to `inventory/services/services.ncl`
- [ ] Nickel contracts pass (`ncl export`)
- [ ] Both guest and host configs build (`build chv-myvm && build britton-desktop`)
- [ ] Secrets generated (`clan vars generate --machine chv-myvm`)
- [ ] Host deployed (`clan machines update britton-desktop`)
- [ ] Disk image bootstrapped (`bootstrap.sh chv-myvm`)
- [ ] VM started and reachable via SSH
- [ ] Guest deployed (`clan machines update chv-myvm`)

## File reference

| File | Purpose |
|------|---------|
| `modules/cloud-hypervisor-vm/default.nix` | Clan service module — generates host-side systemd service |
| `modules/cloud-hypervisor-vm/bootstrap.sh` | One-time disk image creation and NixOS install |
| `inventory/tags/cloud-hypervisor-host.nix` | Host networking: bridge, NAT, dnsmasq, KVM modules |
| `inventory/tags/cloud-hypervisor-guest.nix` | Guest boot config: virtio modules, serial console, networkd |
| `inventory/core/machines.ncl` | Machine registry (name, tags, deploy target) |
| `inventory/services/services.ncl` | Service instances (VM settings per host) |
| `machines/<name>/configuration.nix` | Guest-specific NixOS config |
| `machines/<name>/disko.nix` | Guest disk layout (GPT + ext4, no bootloader) |
