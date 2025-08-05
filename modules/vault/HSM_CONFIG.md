# Vault HSM Auto-Unseal Configuration

This guide covers using a Pico HSM or Nitrokey HSM for Vault auto-unseal.

## Prerequisites

### 1. Install Required Software

```bash
# Install OpenSC (provides PKCS11 support)
sudo apt-get install opensc pcscd pcsc-tools

# Install development tools if building Pico HSM
sudo apt-get install libpcsclite-dev
```

### 2. Verify HSM Detection

```bash
# Check if the HSM is detected
pcsc_scan

# List available PKCS11 slots
pkcs11-tool --module /usr/lib/opensc-pkcs11.so -L
```

## Pico HSM Setup

If using Pico HSM (Raspberry Pi Pico based):

1. **Flash the Pico HSM firmware**:
   - Download from: https://github.com/polhenarejos/pico-hsm
   - Flash to your Raspberry Pi Pico

2. **Initialize the HSM**:
   ```bash
   # Initialize with default PIN (123456)
   pkcs11-tool --module /usr/lib/opensc-pkcs11.so --init-token --label "vault-hsm" --so-pin 3537363231383830
   
   # Change user PIN
   pkcs11-tool --module /usr/lib/opensc-pkcs11.so --init-pin --pin 123456 --new-pin <your-new-pin>
   ```

## Vault Configuration

### 1. Update Vault Module

Add HSM configuration options to the Vault service:

```nix
# In your vault inventory configuration
settings = {
  # Existing settings...
  
  # HSM seal configuration
  seal = {
    pkcs11 = {
      lib = "/usr/lib/opensc-pkcs11.so";
      slot = "0";  # Usually "0" for first HSM
      pin = "your-pin-here";  # Or use environment variable
      key_label = "vault-unseal-key";
      mechanism = "0x1087";  # CKM_AES_GCM
      generate_key = "true";  # Only on first initialization
    };
  };
};
```

### 2. Environment Variables (Alternative)

Instead of hardcoding the PIN, use environment variables:

```nix
systemd.services.vault = {
  environment = {
    VAULT_HSM_LIB = "/usr/lib/opensc-pkcs11.so";
    VAULT_HSM_SLOT = "0";
    VAULT_HSM_KEY_LABEL = "vault-unseal-key";
    VAULT_HSM_MECHANISM = "0x1087";
    VAULT_HSM_GENERATE_KEY = "true";
  };
  
  # Load PIN from a secure file
  serviceConfig = {
    EnvironmentFile = "/etc/vault/hsm-pin.env";  # Contains: VAULT_HSM_PIN=yourpin
  };
};
```

### 3. Migration from Shamir to HSM

To migrate existing Vault from Shamir keys to HSM:

1. **Take a backup** of your Vault data
2. **Create migration config**:
   ```hcl
   seal "pkcs11" {
     lib = "/usr/lib/opensc-pkcs11.so"
     slot = "0"
     pin = "your-pin"
     key_label = "vault-unseal-key"
     mechanism = "0x1087"
     generate_key = "true"
   }
   
   seal "shamir" {
     disabled = true
   }
   ```

3. **Run migration**:
   ```bash
   vault operator unseal -migrate
   # Enter your existing unseal keys
   ```

## Security Considerations

### Pico HSM Limitations

- **No secure element**: Pico HSM uses software-based security
- **Physical access**: No tamper protection
- **Best for**: Development, testing, home labs
- **Not for**: Production with high security requirements

### Production Alternatives

For production, consider:
- **Nitrokey HSM 2**: Hardware secure element
- **YubiHSM 2**: Purpose-built for server applications
- **Cloud HSM**: AWS CloudHSM, Azure Key Vault, GCP Cloud HSM

### Best Practices

1. **PIN Management**:
   - Never hardcode PINs in configuration
   - Use systemd EnvironmentFile or secrets management
   - Rotate PINs regularly

2. **Key Backup**:
   - HSM keys cannot be exported
   - Keep recovery keys in a safe place
   - Consider HSM clustering for redundancy

3. **Monitoring**:
   - Monitor HSM connectivity
   - Alert on unseal failures
   - Log all HSM operations

## Troubleshooting

### Common Issues

1. **HSM not detected**:
   ```bash
   # Restart PC/SC daemon
   sudo systemctl restart pcscd
   
   # Check USB permissions
   sudo usermod -a -G plugdev vault
   ```

2. **PKCS11 module not found**:
   ```bash
   # Find the module
   find /usr -name "*pkcs11*.so" 2>/dev/null
   ```

3. **Wrong PIN or slot**:
   ```bash
   # List slots and tokens
   pkcs11-tool --module /usr/lib/opensc-pkcs11.so -L
   
   # Test login
   pkcs11-tool --module /usr/lib/opensc-pkcs11.so --login --pin <pin> -O
   ```

## Example NixOS Configuration

```nix
{ pkgs, ... }:
{
  # Install required packages
  environment.systemPackages = with pkgs; [
    opensc
    pcsclite
    pcsctools
  ];
  
  # Enable PC/SC daemon
  services.pcscd.enable = true;
  
  # Vault with HSM
  services.vault = {
    # ... existing config ...
    
    extraConfig = ''
      seal "pkcs11" {
        lib = "${pkgs.opensc}/lib/opensc-pkcs11.so"
        slot = "0"
        key_label = "vault-unseal"
        mechanism = "0x1087"
        generate_key = "true"
      }
    '';
  };
  
  # Ensure vault user can access HSM
  users.users.vault.extraGroups = [ "plugdev" ];
}
```