# ACME Certificate Synchronization Service

This document describes the automated certificate synchronization feature of the security-acme module.

## Overview

The controller role provides a systemd user service that automatically retrieves ACME certificates from remote machines and stores them in clan vars. This eliminates the need for manual certificate copying.

## Setup

### 1. Enable the Controller Role

Add the controller role to a machine that has:
- SSH access to ACME provider machines
- The `clan` command available
- Your git repository with clan vars

Example configuration in `inventory/services/security-acme.nix`:

```nix
roles.controller = {
  # Option 1: Use a tag (assign tag to your controller machine)
  tags."controller" = { };
  
  # Option 2: Specify machine directly
  # machines."your-desktop" = { };
  
  settings = {
    syncMachines = {
      britton-fw = {
        certificates = [
          "onix.computer"
          "blr.dev"
        ];
      };
      # Add more machines as needed
    };
    
    syncInterval = "daily";  # or "hourly", "*:0/30", etc.
  };
};
```

### 2. Deploy Configuration

Deploy to your controller machine:
```bash
clan machines update your-desktop
```

### 3. Configure SSH Access

Ensure your controller machine can SSH to ACME providers with sudo access:

```bash
# Test access
ssh britton-fw 'sudo cat /var/lib/acme/onix.computer/fullchain.pem' | head -5
```

For passwordless operation, configure sudoers on the ACME provider:
```
your-user ALL=(ALL) NOPASSWD: /bin/cat /var/lib/acme/*/fullchain.pem, /bin/cat /var/lib/acme/*/key.pem
```

## Usage

### Manual Sync

Run the sync service manually:
```bash
systemctl --user start acme-cert-sync.service
```

Check status:
```bash
systemctl --user status acme-cert-sync.service
```

View logs:
```bash
journalctl --user -u acme-cert-sync.service -f
```

### Automatic Sync

The timer runs automatically based on `syncInterval`. Check timer status:
```bash
systemctl --user status acme-cert-sync.timer
```

### Verify Certificates

Check stored certificates:
```bash
clan vars get britton-fw security-acme-certs/onix.computer.crt
```

## How It Works

1. The service runs on your controller machine as a user service
2. It SSHs to each configured machine
3. Retrieves certificates using `sudo cat`
4. Stores them in clan vars under `security-acme-certs/`
5. The timer ensures regular updates

## Troubleshooting

### Service fails to start
- Check that `clan` command is in PATH
- Verify SSH access to remote machines
- Check systemd user service logs

### Permission denied
- Ensure sudo access on remote machines
- Check SSH key authentication

### Certificates not found
- Verify certificate names match what's in `/var/lib/acme/`
- Ensure ACME service has run on the provider machine

## Security Notes

- Runs as user service (not system service) for access to SSH keys
- Uses existing SSH authentication
- Certificates are transmitted over SSH
- Private keys require sudo access on remote machines