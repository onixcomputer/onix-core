# Clan Vars Decryption Test Module

A simple NixOS service module that tests whether a machine can successfully decrypt clan vars.

## Purpose

This module creates a dedicated test var and verifies that the machine can:
1. Access the clan vars system
2. Decrypt secrets it has access to
3. Read the decrypted content correctly

## How It Works

The module automatically creates a test generator (`clan-vars-decryption-test-{instanceName}`) with a test secret file. When the test runs, it:
1. Attempts to read the test secret file
2. Verifies the content matches the expected value
3. Reports success or failure

## Configuration

### Basic Setup

```nix
{
  instances = {
    "vars-decryption-test" = {
      module.name = "clan-devshell";
      module.input = "self";
      roles.developer = {
        machines."your-machine" = { };
        
        settings = {
          enable = true;
          enableSystemdService = true;
          testInterval = "daily";
        };
      };
    };
  };
}
```

## Options

### `enable`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable the vars decryption test on this machine

### `enableSystemdService`
- **Type**: boolean
- **Default**: `true`
- **Description**: Enable systemd service to periodically run the test

### `testInterval`
- **Type**: string
- **Default**: `"hourly"`
- **Description**: How often to run the test (systemd timer format: hourly, daily, weekly, etc.)

## Usage

### Manual Testing

Once deployed to a machine:

```bash
# Run the decryption test
clan-vars-test

# Check the test configuration
clan-vars-status
```

### Systemd Service

If `enableSystemdService` is enabled:

```bash
# Check service status
systemctl status clan-vars-test-vars-decryption-test

# Check timer status
systemctl status clan-vars-test-vars-decryption-test.timer

# View test logs
journalctl -u clan-vars-test-vars-decryption-test
```

## Output Example

### Success
```
╔══════════════════════════════════════════════════════╗
║        Clan Vars Decryption Test - vars-decryption-test║
╚══════════════════════════════════════════════════════╝

Testing decryption test var... ✓ PASSED

This machine can successfully decrypt clan vars!
Test var content verified: DECRYPTION_TEST_SUCCESSFUL
```

### Failure
```
╔══════════════════════════════════════════════════════╗
║        Clan Vars Decryption Test - vars-decryption-test║
╚══════════════════════════════════════════════════════╝

Testing decryption test var... ✗ FAILED

Test var file not accessible at: /var/lib/clan-vars/generators/clan-vars-decryption-test-vars-decryption-test/test-secret
Run 'clan vars generate' to create the test var.
```

## Troubleshooting

### Test Failing

If the test is failing:

1. Check if the test generator was created:
   ```bash
   clan vars list | grep decryption-test
   ```

2. Generate the test var:
   ```bash
   clan vars generate
   ```

3. Check if the file exists:
   ```bash
   ls -la /var/lib/clan-vars/generators/clan-vars-decryption-test-*/
   ```

4. Verify machine configuration and deployment

### First Deployment

On the first deployment to a machine, you may need to run `clan vars generate` once to create the test var before the test will pass.