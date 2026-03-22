## MODIFIED Requirements

### Requirement: TAP interface lifecycle
The host service ExecStartPre SHALL delete any existing TAP interface before creating a fresh one with the correct flags.

#### Scenario: Clean TAP creation on service start
- **WHEN** the cloud-hypervisor service starts and a stale TAP interface exists from a previous crashed run
- **THEN** the stale TAP is deleted and a new TAP is created with `multi_queue` and `vnet_hdr` flags matching the VM's vCPU count

#### Scenario: Fresh TAP creation on first start
- **WHEN** the cloud-hypervisor service starts and no TAP interface exists
- **THEN** a new TAP is created with `multi_queue` and `vnet_hdr` flags

### Requirement: dnsmasq interface notification
The host service SHALL notify dnsmasq to rescan interfaces after creating the TAP.

#### Scenario: dnsmasq detects TAP immediately
- **WHEN** the TAP interface is created and assigned 172.16.0.1/24 in ExecStartPre
- **THEN** dnsmasq receives SIGHUP and begins listening for DHCP requests on the TAP subnet before the guest's first DHCP discover

### Requirement: Graceful VM shutdown
The host service ExecStop SHALL use the cloud-hypervisor API socket to send an ACPI power button event, allowing the guest to shut down cleanly.

#### Scenario: Clean shutdown via systemctl stop
- **WHEN** `systemctl stop cloud-hypervisor-chv-dev1` is run
- **THEN** the guest receives ACPI power button, systemd inside the guest runs shutdown, filesystems are synced, and cloud-hypervisor exits cleanly without dirty ext4 flags
