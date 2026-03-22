## 1. Serial Console Diagnostics

- [x] 1.1 Read boot journal output from `journalctl -u cloud-hypervisor-chv-dev1` on britton-desktop — FINDING: guest stuck in initrd emergency mode, `initrd-find-nixos-closure` fails because host service references new toplevel (post-rebuild) but disk image has old closure. The `init=` path doesn't exist on disk.
- [x] 1.2 Get interactive serial console access — switched to `--serial pty`, found PTY at `/dev/pts/11` via ch-remote API
- [x] 1.3 `ip link show`: ens2 is UP,LOWER_UP with carrier, MAC 52:54:00:c0:ff:01, multi-queue 4/4
- [x] 1.4 `networkctl status ens2`: matched 10-virtio.network, Driver=virtio_net, state=carrier(failed), ActivationPolicy=up confirmed
- [x] 1.5 `journalctl -u systemd-networkd`: **"Failed to configure DHCPv4 client: No such file or directory"** — repeated ENOENT on every DHCP attempt
- [x] 1.6 `cat /proc/net/dev`: ens2 TX=7 packets (IPv6 ND only), no DHCP packets sent
- [x] 1.7 ROOT CAUSE: `/etc/machine-id` missing. systemd-networkd's DHCPv4 client needs machine-id for DUID generation. nixos-install in chroot can't create it when /etc/ is a read-only nix store overlay. Fix: generate machine-id explicitly in bootstrap script after nixos-install.

## 2. Guest Networking Configuration Fix

- [x] 2.1 Update `inventory/tags/cloud-hypervisor-guest.nix` — change networkd match from `Name = "ens*"` to `Driver = "virtio_net"` for name-independent matching
- [x] 2.2 Add `ConfigureWithoutCarrier = yes` to the .network file's `[Network]` section to handle TAP carrier timing
- [x] 2.3 Add `ActivationPolicy = "up"` to the .network file's `[Link]` section to force interface UP unconditionally
- [x] 2.4 Verify generated .network file is correct: `nix build .#nixosConfigurations.chv-dev1.config.system.build.toplevel` and inspect `/etc/systemd/network/10-virtio.network` in the output — confirmed: `[Match] Driver=virtio_net`, `[Link] ActivationPolicy=up`, `[Network] ConfigureWithoutCarrier=true DHCP=yes IPv6AcceptRA=true`

## 3. Host Launcher TAP Fix

- [x] 3.1 Update `modules/cloud-hypervisor-vm/default.nix` ExecStartPre — change TAP creation from "create-if-missing" to "delete+recreate" pattern (match microvm.nix behavior)
- [x] 3.2 Add SIGHUP to dnsmasq after TAP creation in ExecStartPre to force immediate interface rescan
- [x] 3.3 Multi-queue NOT the root cause — networking works with num_queues=8 (4 queue pairs). Root cause was missing /etc/machine-id. No changes needed.
- [x] 3.4 Verify britton-desktop builds with changes: `build britton-desktop` — toplevel: /nix/store/17h03kxwzg7b3ancvn49vqn2bya183rx-nixos-system-britton-desktop-26.05.20260316.f8573b9

## 4. Deploy and Validate

- [x] 4.1 Deploy host changes to britton-desktop: `clan machines update britton-desktop` — deployed, cloud-hypervisor-chv-dev1.service now exists
- [x] 4.2 Re-bootstrapped guest disk image, discovered machine-id was missing, created it manually. Fixed bootstrap.sh to auto-generate machine-id.
- [x] 4.3 VM started, DHCP lease acquired: `172.16.0.10` for MAC `52:54:00:c0:ff:01`. dnsmasq lease file confirms. ARP REACHABLE.
- [x] 4.4 SSH from host works: `ssh root@172.16.0.10` via brittonr's ed25519 key (root key delegation from shared-users.nix)
- [x] 4.5 Outbound internet works: `curl -s https://nixos.org` returns HTTP 200 from 99.83.231.61 inside guest

## 5. Complete Parent Change Validation Tasks

- [x] 5.1 Graceful shutdown works: `systemctl stop` completes in 2.1s, ACPI power-button used, ExecStop exit 0, `e2fsck: clean` on disk image
- [x] 5.2 `clan machines update chv-dev1` deployed successfully — built on britton-desktop, copied closure, activated. Required: buildHost=britton-desktop, root SSH config for guest IP, host key in known_hosts.
- [x] 5.3 VM restart verified — `systemctl restart` completes, guest re-acquires DHCP lease 172.16.0.10, SSH reachable within 15 seconds
- [x] 5.4 Nix GC verified: timer active (triggers daily at midnight), manual run freed 6.1 MiB, `--delete-older-than 7d` option confirmed
- [x] 5.5 Added `machines/chv-dev1/README.md` with: network info, lifecycle commands, bootstrap procedure, serial console access, disk resize steps, VM specs
