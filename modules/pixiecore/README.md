# Pixiecore PXE Boot Service

This module provides a Pixiecore-based PXE boot server for network booting NixOS systems.

## Features

- **Automatic SSH Key Injection**: When SSH keys are configured, the module automatically builds a custom NixOS netboot image with the keys embedded
- **Multiple Boot Modes**: Supports API mode for dynamic configuration or boot mode for static kernel/initrd
- **DHCP Proxy**: Works alongside existing DHCP servers without conflicts
- **Minimal Configuration**: Simple setup with sensible defaults

## Configuration

### Basic Setup

```nix
# In inventory/services/pixiecore.nix
{
  roles.server = {
    machines = [ "britton-fw" ];
    settings = {
      enable = true;
      sshAuthorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
      ];
    };
  };
}
```

### Advanced Configuration with Freeform Options

The module supports freeform options for customizing the netboot image:

```nix
{
  roles.server = {
    machines = [ "britton-fw" ];
    settings = {
      enable = true;
      sshAuthorizedKeys = [ "ssh-ed25519 ..." ];
      
      # Add extra packages to the netboot image
      netbootPackages = with pkgs; [
        git
        nmap
        pciutils
        usbutils
      ];
      
      # Add custom NixOS configuration
      netbootConfig = {
        # Set a custom hostname
        networking.hostName = "pxe-installer";
        
        # Enable additional services
        services.nginx.enable = true;
        
        # Custom kernel parameters
        boot.kernelParams = [ "console=ttyS0,115200" ];
        
        # Add custom users
        users.users.installer = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];
        };
      };
      
      # Pass any other pixiecore options
      extraOptions = [ "--debug" "--dhcp-timeout=10s" ];
    };
  };
}
```

### Network Configuration

On your router/DHCP server, configure:
- **Next Server**: IP address of the pixiecore host (e.g., 192.168.1.140)
- **Boot Filename**: Leave empty - pixiecore handles this via DHCP proxy

## How It Works

The module always builds a custom NixOS netboot image based on the minimal installer profile. This provides a consistent, predictable netboot environment that includes all configured packages and settings.

### Custom Netboot Features

The custom netboot always includes:
- OpenSSH server enabled with root login
- SSH keys pre-installed for root user
- Password authentication disabled
- Basic utilities (vim, curl, wget, htop, tmux)
- **nixos-facter** for generating hardware configuration
- DHCP networking enabled
- Firewall disabled for easy access

## Usage

### Building and Deploying

```bash
# Build the configuration
clan machines build britton-fw

# Deploy to the host
clan machines update britton-fw
```

### Testing PXE Boot

1. Enable PXE/network boot on client machine
2. Boot the client - it should receive boot instructions from pixiecore
3. The system will boot into NixOS with SSH access enabled
4. SSH to the booted system: `ssh root@<client-ip>`

### Using nixos-facter

Once connected to a netbooted system, you can use nixos-facter to generate hardware configuration:

```bash
# Generate hardware report
nixos-facter

# Save the configuration for later use
nixos-facter > hardware-config.json

# The JSON output includes:
# - System details (manufacturer, model, etc.)
# - CPU information
# - Memory configuration
# - Storage devices and partitions
# - Network interfaces
# - Boot configuration
```

This is particularly useful for:
- Documenting hardware before installation
- Generating NixOS hardware configurations
- Inventory management
- Debugging hardware issues

### Monitoring

```bash
# Check service status
systemctl status pixiecore

# View logs
journalctl -u pixiecore -f

# Check what files are being served
ps aux | grep pixiecore
```

## Architecture

The module operates in a single, simplified mode:

### Boot Mode
- Always builds custom netboot using NixOS's netboot-minimal profile
- Serves kernel and initrd directly via pixiecore
- No additional services needed
- Supports full customization via freeform options

## Files

- `default.nix`: Main module definition
- `netboot-with-ssh.nix`: Custom netboot configuration (historical reference)
- `inject-ssh-keys.sh`: Script for manual initrd modification (historical reference)
- `build-netboot.sh`: Manual build script (historical reference)

## Troubleshooting

### Client Not Booting
- Verify DHCP next-server points to pixiecore host
- Check firewall allows UDP 67, 68, 69, 4011
- Ensure pixiecore service is running: `systemctl status pixiecore`

### No SSH Access
- Verify SSH keys are correctly configured in the module
- Check the booted system received an IP address
- Ensure client firewall/network allows SSH connections

### Build Failures
- Check for conflicts with `networking.useDHCP` (module uses `lib.mkDefault`)
- Verify system has sufficient resources to build custom images