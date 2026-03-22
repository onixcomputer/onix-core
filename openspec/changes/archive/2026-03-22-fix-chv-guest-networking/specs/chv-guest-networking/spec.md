## ADDED Requirements

### Requirement: Guest obtains IP via DHCP
The cloud-hypervisor guest SHALL obtain an IPv4 address from the host's dnsmasq DHCP server via the virtio-net interface over the TAP tunnel.

#### Scenario: DHCP lease acquired on boot
- **WHEN** the guest boots to multi-user.target
- **THEN** systemd-networkd acquires a DHCP lease and the virtio-net interface has IP 172.16.0.10/24 (per dnsmasq reservation for MAC 52:54:00:c0:ff:01)

#### Scenario: Default route via host gateway
- **WHEN** the guest acquires a DHCP lease
- **THEN** the default route points to 172.16.0.1 (the host TAP endpoint) and DNS resolvers are set to 1.1.1.1 and 8.8.8.8 (per dnsmasq dhcp-option)

### Requirement: Guest reachable via SSH from host
The host SHALL be able to SSH into the guest at its DHCP-assigned IP after boot completes.

#### Scenario: SSH connection from host
- **WHEN** the guest has booted and obtained its DHCP lease
- **THEN** `ssh root@172.16.0.10` from the host connects to the guest's OpenSSH daemon

### Requirement: Guest has outbound internet via NAT
The guest SHALL reach external hosts via the host's NAT configuration.

#### Scenario: DNS resolution and HTTP from guest
- **WHEN** the guest has networking and the host has NAT enabled on the TAP interface
- **THEN** the guest can resolve DNS names and reach external HTTP endpoints (e.g., `curl -s https://nixos.org`)

### Requirement: Clan deploy over SSH
`clan machines update chv-dev1` SHALL deploy NixOS configuration changes to the guest over SSH.

#### Scenario: Successful clan deploy
- **WHEN** the guest has SSH connectivity and a valid system closure
- **THEN** `clan machines update chv-dev1` builds, copies the closure, and activates the new system on the guest

### Requirement: Networking survives VM restart
Guest networking SHALL work after `systemctl restart cloud-hypervisor-chv-dev1` on the host.

#### Scenario: DHCP re-acquisition after restart
- **WHEN** the host stops and restarts the cloud-hypervisor service (TAP destroyed+recreated, VM reboots)
- **THEN** the guest re-acquires its DHCP lease and is reachable via SSH within 30 seconds of boot
