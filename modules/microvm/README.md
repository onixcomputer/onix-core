# MicroVM Clan Service Module

This module provides a declarative way to manage lightweight virtual machines using the microvm.nix framework within the clan-core infrastructure.

## Features

- **Multiple VM Instances**: Support for multiple microVMs per machine
- **Resource Management**: Configurable CPU, memory, and disk allocations
- **Network Configuration**: Flexible networking with tap interfaces and VSOCK support
- **Security Hardening**: Built-in systemd service hardening options
- **Credential Management**: Secure passing of secrets from host to guest via systemd credentials
- **Modular Guest Configuration**: Support for custom NixOS modules in guest VMs
- **Automatic Secret Generation**: Integration with clan vars for automatic secret generation

## Module Structure

The module follows the standard clan service pattern with perInstance support:

```nix
{
  _class = "clan.service";
  manifest = { name = "microvm"; ... };
  roles = {
    server = {
      interface = { ... };  # Configuration options
      perInstance = { ... }; # Per-instance NixOS module generation
    };
  };
}
```

## Configuration Options

### Core VM Settings

- `vmName` - Name of the microVM instance
- `autostart` - Whether to start on boot (default: true)
- `hypervisor` - Backend to use: cloud-hypervisor, qemu, firecracker, etc.

### Resources

- `vcpu` - Number of virtual CPUs (default: 2)
- `mem` - Memory in MB (default: 1024)
- `balloonMem` - Optional memory balloon size for dynamic management

### Networking

- `interfaces` - List of network interfaces (tap, bridge, etc.)
- `vsockCid` - VSOCK CID for host-guest communication (null to disable)
- `firewallPorts` - TCP ports to open in guest firewall

### Storage

- `shares` - Shared filesystem mounts from host to guest
- `volumes` - Additional disk volumes to attach

### Security & Credentials

- `credentialPrefix` - Prefix for credential names (default: "HOST-")
- `credentials` - Map of credentials to pass from host to guest
- `staticOemStrings` - Static configuration via OEM strings
- `serviceHardening` - Systemd service hardening options

### Guest Configuration

- `guestModules` - Additional NixOS modules for the guest
- `guestHostname` - Hostname for the guest
- `guestStateVersion` - NixOS state version
- `guestPackages` - Packages to install in guest
- `enableSsh` - Enable SSH server (default: true)
- `rootPassword` - Root password (null for disabled)
- `authorizedKeys` - SSH authorized keys for root

## Usage Examples

### Basic Test VM

```nix
{
  instances = {
    "test-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines.my-machine = {
          vmName = "test-vm";
          vcpu = 2;
          mem = 1024;

          interfaces = [{
            type = "tap";
            id = "vm-test";
            mac = "02:00:00:01:01:01";
          }];

          rootPassword = "test";
          enableSsh = true;
        };
      };
    };
  };
}
```

### VM with Secrets

```nix
{
  instances = {
    "secure-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines.my-machine = {
          vmName = "secure";

          credentials = {
            api-key = {
              source = "/run/secrets/api-key";
              destination = "API-KEY";
            };
          };

          staticOemStrings = [
            "io.systemd.credential:ENVIRONMENT=production"
          ];

          guestModules = [
            ({ ... }: {
              systemd.services.my-service = {
                serviceConfig.LoadCredential = [
                  "api-key:HOST-API-KEY"
                ];
              };
            })
          ];
        };
      };
    };
  };
}
```

### VM with Enhanced Security

```nix
{
  instances = {
    "hardened-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines.my-machine = {
          vmName = "hardened";

          serviceHardening = {
            enable = true;
            protectProc = "noaccess";
            procSubset = "pid";
            protectHome = true;
            restrictAddressFamilies = [
              "AF_UNIX" "AF_VSOCK" "AF_INET" "AF_INET6"
            ];
          };

          rootPassword = null; # No password
          authorizedKeys = [ "ssh-ed25519 AAAA..." ];
        };
      };
    };
  };
}
```

## Integration with Existing Test-VM

To migrate the existing test-vm configuration from `machines/britton-desktop/configuration.nix` to use this module:

1. Enable the microvm service in inventory
2. Configure the instance with matching parameters
3. Remove the old direct microvm configuration
4. Deploy using `clan machines update britton-desktop`

## Managing VMs

### Start/Stop VMs

```bash
# Start a VM
systemctl start microvm@test-vm

# Stop a VM
systemctl stop microvm@test-vm

# Check VM status
systemctl status microvm@test-vm
```

### Access VM Console

```bash
# Connect to VM console
microvm -S /var/lib/microvms/test-vm/test-vm.sock
```

### Generate Secrets

```bash
# Generate clan vars for the VM
clan vars generate --machine britton-desktop
```

## Troubleshooting

### VM Won't Start

- Check logs: `journalctl -u microvm@vm-name`
- Verify network interfaces are available
- Ensure hypervisor support (KVM) is enabled
- Check credential paths exist

### Credentials Not Available in Guest

- Verify LoadCredential in host systemd service
- Check credential prefix matches (HOST- by default)
- Ensure OEM string support for your hypervisor
- Verify systemd-creds in guest: `systemd-creds list`

### Network Issues

- Check tap interface creation permissions
- Verify MAC addresses are unique
- Ensure firewall rules allow VM traffic
- Check bridge configuration if using bridged networking

## Implementation Notes

The module uses several key patterns:

1. **perInstance Pattern**: Each VM instance gets its own configuration namespace
2. **Credential Flow**: Host → LoadCredential → OEM Strings → Guest systemd
3. **Service Hardening**: Applied at the systemd service level, not guest
4. **Module Composition**: Guest modules are merged with base configuration

## Future Enhancements

Potential improvements to consider:

- GPU passthrough support
- USB device passthrough
- Live migration capabilities
- Snapshot and restore functionality
- Network isolation policies
- Resource quotas and limits
- Integration with monitoring systems