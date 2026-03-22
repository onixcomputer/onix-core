## ADDED Requirements

### Requirement: Serial console output capture
The host SHALL be able to read serial console output from a running cloud-hypervisor guest via `journalctl -u cloud-hypervisor-<name>`.

#### Scenario: Boot log visible in host journal
- **WHEN** the cloud-hypervisor VM service starts with `--serial tty`
- **THEN** the guest kernel boot log and systemd service output appear in the host's systemd journal for that unit

### Requirement: Serial console interactive access
The host SHALL provide a mechanism to send commands to the guest via serial console without SSH.

#### Scenario: Run diagnostic command via serial PTY
- **WHEN** the cloud-hypervisor service is running and the serial console is accessible
- **THEN** the operator can send a shell command (e.g., `ip link show`) and read the output via the serial device

### Requirement: Network diagnostic commands
The following diagnostic commands SHALL be executable inside the guest via serial console to determine networking state:
- `ip link show` — interface flags (UP, LOWER_UP, NO-CARRIER)
- `ip addr show` — assigned IP addresses
- `networkctl` — systemd-networkd operational summary
- `networkctl status <iface>` — detailed interface state and matched .network file
- `journalctl -u systemd-networkd -n 50` — recent networkd log entries
- `cat /proc/net/dev` — kernel packet counters (TX/RX per interface)

#### Scenario: Determine if interface is administratively UP
- **WHEN** `ip link show ens2` is run inside the guest
- **THEN** the output shows whether the interface has UP and LOWER_UP flags, indicating admin and carrier state

#### Scenario: Determine if DHCP client sent packets
- **WHEN** `cat /proc/net/dev` is run inside the guest
- **THEN** the TX packet count for the virtio-net interface shows whether any packets were transmitted by the guest kernel
