# Systemd Service Orchestration for Garage and Keycloak-Terraform

This document describes the complete systemd service orchestration design for integrating Garage S3-compatible storage with Keycloak Terraform automation.

## Service Dependency Chain

The orchestration follows a strict dependency chain to ensure proper startup order and health:

```
1. garage.service (Type=simple)
   ↓ (After/Requires)
2. garage-bucket-init.service (Type=oneshot, RemainAfterExit=true)
   ↓ (After/Requires)
3. garage-key-init.service (Type=oneshot, RemainAfterExit=true)
   ↓ (After/Requires)
4. keycloak.service (Type=simple) [parallel startup with Garage]
   ↓ (After/Requires both keycloak + garage-key-init)
5. keycloak-terraform.service (Type=oneshot, RemainAfterExit=true)
```

## Service Definitions

### 1. garage.service
- **Type**: `simple`
- **Purpose**: Run Garage S3-compatible distributed storage
- **Dependencies**: `network.target`
- **Security**: Full systemd hardening (NoNewPrivileges, ProtectSystem, etc.)
- **Configuration**: Generated from Nix configuration with clan vars for secrets

### 2. garage-bucket-init.service
- **Type**: `oneshot`
- **Purpose**: Initialize Terraform state bucket in Garage
- **Dependencies**: `garage.service` (After/Requires)
- **RemainAfterExit**: `true`
- **Health Check**: Waits for Garage admin API on port 3903
- **Retry**: On failure with 10s delay
- **Timeout**: 5 minutes

### 3. garage-key-init.service
- **Type**: `oneshot`
- **Purpose**: Create access keys and credentials for Terraform
- **Dependencies**: `garage-bucket-init.service` (After/Requires)
- **RemainAfterExit**: `true`
- **Credential Storage**: `/run/credentials/garage-terraform/`
- **Permissions**: 600 on credential files
- **Retry**: On failure with 10s delay

### 4. keycloak-terraform.service
- **Type**: `oneshot`
- **Purpose**: Execute Terraform configuration for Keycloak resources
- **Dependencies**: `keycloak.service` + `garage-key-init.service` (After/Requires)
- **RemainAfterExit**: `true`
- **Working Directory**: `/var/lib/keycloak-terraform`
- **Timeout**: 20 minutes for complex Terraform operations
- **Retry**: On failure with 30s delay

## Service Ordering and Dependencies

### Dependency Types Used

1. **After**: Service starts after dependency
2. **Requires**: Service fails if dependency fails
3. **PartOf**: Not used (would cause cascading stops)
4. **Wants**: Not used (would allow optional dependencies)

### Why This Design

- **Requires over Wants**: Ensures strict dependency enforcement
- **After + Requires**: Guarantees both ordering and dependency
- **Type=oneshot with RemainAfterExit=true**: Perfect for initialization tasks
- **Type=simple**: For long-running services (garage, keycloak)

## Credential Passing Between Services

### Mechanism: SystemD LoadCredential + Runtime Directories

1. **garage-key-init.service**:
   - Creates `/run/credentials/garage-terraform/access_key_id`
   - Creates `/run/credentials/garage-terraform/secret_access_key`
   - Sets permissions to 600
   - Uses RuntimeDirectory for secure storage

2. **keycloak-terraform.service**:
   - Uses `LoadCredential` to access Garage credentials
   - Loads Keycloak admin password from clan vars
   - Environment variables for Terraform:
     ```bash
     AWS_ACCESS_KEY_ID=$(cat /run/credentials/garage-terraform/access_key_id)
     AWS_SECRET_ACCESS_KEY=$(cat /run/credentials/garage-terraform/secret_access_key)
     TF_VAR_keycloak_admin_password=$(cat ${clan-vars-path})
     ```

### Security Features

- **DynamicUser**: All services run as dynamic users
- **RuntimeDirectory**: Secure credential storage
- **LoadCredential**: SystemD's secure credential mechanism
- **NoNewPrivileges**: Prevents privilege escalation
- **ProtectSystem**: Read-only system files
- **SystemCallFilter**: Restricts available system calls

## Wait/Health Check Mechanisms

### Garage Health Checks

```bash
# Wait for Garage admin API
for i in {1..60}; do
  if curl -sf "http://localhost:3903/health" >/dev/null 2>&1 || \
     nc -z localhost 3903 >/dev/null 2>&1; then
    echo "Garage ready!"
    break
  fi
  sleep 5
done
```

### Keycloak Health Checks

```bash
# Multi-step health verification
1. Check admin console accessibility: http://localhost:8080/auth/admin/
2. Verify authentication with admin credentials
3. Test token endpoint: /auth/realms/master/protocol/openid-connect/token
```

### Retry Logic

- **Exponential backoff**: 5s → 10s → 30s delays
- **Maximum attempts**: 60 for basic health, 120 for complex checks
- **Timeout limits**: 5min for init, 20min for Terraform
- **Failure handling**: Service marked as failed, logged for debugging

## Restart and Failure Handling

### Restart Policies

1. **garage.service**: `Restart=on-failure, RestartSec=5s`
2. **Oneshot services**: `Restart=on-failure` (limited attempts)
3. **Monitor service**: Periodic health checks via timer

### Failure Scenarios

1. **Garage startup failure**: All dependent services fail
2. **Bucket init failure**: Retry with exponential backoff
3. **Credential generation failure**: Manual intervention required
4. **Terraform failure**: Detailed logging, state preserved
5. **Keycloak unavailable**: Wait and retry up to 10 minutes

### Recovery Mechanisms

```bash
# Manual recovery commands
systemctl restart garage.service                    # Restart storage
systemctl restart garage-bucket-init.service        # Retry bucket creation
systemctl restart garage-key-init.service          # Regenerate credentials
systemctl restart keycloak-terraform.service       # Retry Terraform
```

## Resource Limits and Security

### Memory Limits
- **garage.service**: 2GB maximum
- **keycloak-terraform.service**: 1GB maximum
- **Init services**: Default limits

### Security Hardening
- **DynamicUser**: No persistent user accounts
- **ProtectSystem=strict**: Read-only system files
- **PrivateTmp**: Isolated temporary directories
- **PrivateDevices**: No device access
- **SystemCallFilter**: Restricted system calls
- **NoNewPrivileges**: Prevent privilege escalation

### Network Security
- **Garage**: Binds admin API to localhost only
- **Firewall**: Only necessary ports opened (3900, 3903)
- **TLS**: Optional for external access

## Monitoring and Observability

### Service Status Monitoring

```bash
# Check all service status
systemctl status garage.service
systemctl status garage-bucket-init.service
systemctl status garage-key-init.service
systemctl status keycloak-terraform.service

# Monitor logs
journalctl -u garage.service -f
journalctl -u keycloak-terraform.service -f
```

### Health Check Timer

- **garage-terraform-monitor.timer**: Runs every hour
- **Health verification**: All services active and healthy
- **Alerting**: Logs warnings for failed services

## Integration with Existing Infrastructure

### Clan Vars Integration

```nix
clan.core.vars.generators.garage = {
  files = {
    rpc_secret = { };
    admin_token = { };
  };
  script = ''
    pwgen -s 64 1 > "$out"/rpc_secret
    pwgen -s 32 1 > "$out"/admin_token
  '';
};
```

### Terraform Backend Configuration

```hcl
terraform {
  backend "s3" {
    endpoint = "http://localhost:3900"
    bucket = "keycloak-terraform-state"
    key = "keycloak/terraform.tfstate"
    region = "garage"

    skip_region_validation = true
    skip_credentials_validation = true
    force_path_style = true
  }
}
```

## Usage Examples

### Basic Configuration

```nix
{
  services.garage-terraform.enable = true;
  services.garage-terraform.garageConfig = ''
    metadata_dir = "/var/lib/garage/meta"
    data_dir = "/var/lib/garage/data"
    replication_mode = "1"
    # ... (see garage-config-example.nix)
  '';
}
```

### Advanced Configuration with Keycloak Service

```nix
{
  # Enable both services
  services.garage-terraform.enable = true;

  # Keycloak service with Terraform integration
  services.keycloak = {
    enable = true;
    terraform = {
      enable = true;
      # ... Terraform resources configuration
    };
  };
}
```

This orchestration provides a robust, secure, and maintainable solution for integrating Garage storage with Keycloak Terraform automation using systemd best practices.