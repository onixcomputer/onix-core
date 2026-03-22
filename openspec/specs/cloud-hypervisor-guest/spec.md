## MODIFIED Requirements

### Requirement: networkd interface matching
The guest's systemd-networkd .network file SHALL match the virtio-net interface by kernel driver name, not by predictable interface name.

#### Scenario: Match by driver regardless of interface name
- **WHEN** the virtio-net interface appears as ens2, enp0s3, or any other predictable name
- **THEN** the .network file matches via `Driver=virtio_net` and DHCP is initiated on the interface

### Requirement: Carrier-independent DHCP activation
The guest's .network configuration SHALL start DHCP even if the interface initially reports no carrier.

#### Scenario: DHCP starts before carrier is detected
- **WHEN** the virtio-net interface is created but carrier is not yet reported (TAP timing race)
- **THEN** networkd begins DHCP attempts immediately due to `ConfigureWithoutCarrier=yes` and succeeds once carrier arrives

### Requirement: Interface brought UP unconditionally
The guest's .network configuration SHALL force the virtio-net interface administratively UP via `ActivationPolicy=up`.

#### Scenario: Interface UP without waiting for carrier
- **WHEN** networkd matches the .network file to the virtio-net interface
- **THEN** the interface is set to admin state UP regardless of carrier state, enabling the DHCP client to send discover packets

### Requirement: Automatic nix store garbage collection
The guest SHALL run nix garbage collection automatically to prevent the fixed-size disk image from filling up.

#### Scenario: Old closures cleaned daily
- **WHEN** the guest has been running for more than 24 hours and previous system generations exist
- **THEN** nix GC runs and deletes closures older than 7 days, freeing disk space on the fixed-size image
