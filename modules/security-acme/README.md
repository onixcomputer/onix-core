# Security ACME Clan Service

A clan service for managing ACME certificates using NixOS's `security.acme` module. This service enables:

- Certificate generation on designated provider machines
- Automatic certificate sharing via clan vars
- Multi-machine certificate distribution
- Support for wildcard certificates
- DNS challenge support with multiple providers

## Architecture

The service uses a provider/consumer model:

- **Provider**: Machines that generate certificates using Let's Encrypt
- **Consumer**: Machines that need to use certificates generated elsewhere

Certificates are automatically synchronized to clan vars for secure distribution across machines.

## Basic Usage

### Single Machine (Provider Only)

For a simple setup where one machine generates and uses its own certificates:

```nix
# inventory/services/security-acme.nix
{
  roles.provider = {
    tags."cert-provider" = { };
    settings = {
      email = "admin@example.com";
      acceptTerms = true;
      
      # Standard certificates
      certs."example.com" = {
        extraDomainNames = [ "www.example.com" ];
      };
    };
  };
}
```

### Multi-Machine with Shared Wildcard

Generate a wildcard certificate on one machine and share it with others:

```nix
# inventory/services/security-acme.nix
{
  # Certificate provider machine
  roles.provider = {
    tags."cert-provider" = { };
    settings = {
      email = "admin@example.com";
      acceptTerms = true;
      
      # Share a wildcard certificate
      shareWildcard = true;
      wildcardDomain = "*.example.com";
      
      # DNS challenge configuration
      dnsProvider = "cloudflare";
      environmentFile = config.clan.core.vars.generators.security-acme-dns.files.cloudflare_env.path;
      
      # Also share specific certificates
      certificatesToShare = [ "api.example.com" ];
      
      # Configure the specific certificate
      certs."api.example.com" = {
        extraDomainNames = [ "api-v2.example.com" ];
      };
    };
  };
  
  # Consumer machines
  roles.consumer = {
    tags."web-server" = { };
    settings = {
      certificates = {
        # Use the shared wildcard
        wildcard = {
          domain = "*.example.com";
          reloadServices = [ "nginx.service" ];
          group = "nginx";
        };
        
        # Use the shared API certificate
        api = {
          domain = "api.example.com";
          reloadServices = [ "myapi.service" ];
        };
      };
    };
  };
}
```

## Integration with Services

### Nginx Example

```nix
# On consumer machine
{
  services.nginx = {
    enable = true;
    virtualHosts."app.example.com" = {
      forceSSL = true;
      sslCertificate = config.services.security-acme.consumer.certificates.wildcard.certPath;
      sslCertificateKey = config.services.security-acme.consumer.certificates.wildcard.keyPath;
      locations."/".root = "/var/www/app";
    };
  };
}
```

### Traefik Integration

```nix
# Configure Traefik to use external certificates
{
  services.traefik = {
    dynamicConfigOptions.tls.certificates = [{
      certFile = config.services.security-acme.consumer.certificates.wildcard.certPath;
      keyFile = config.services.security-acme.consumer.certificates.wildcard.keyPath;
    }];
  };
}
```

## Advanced Configuration

### Multiple DNS Providers

The service supports freeform configuration, allowing any `security.acme` options:

```nix
roles.provider = {
  settings = {
    email = "admin@example.com";
    acceptTerms = true;
    
    # Different certificates with different providers
    certs = {
      "example.com" = {
        dnsProvider = "cloudflare";
        credentialsFile = "/path/to/cloudflare-creds";
      };
      
      "internal.corp" = {
        dnsProvider = "route53";
        credentialsFile = "/path/to/aws-creds";
      };
      
      "public.site" = {
        # Use HTTP challenge instead
        webroot = "/var/lib/acme/acme-challenge";
      };
    };
    
    # Share specific certificates
    certificatesToShare = [ "example.com" "internal.corp" ];
  };
};
```

### Certificate Renewal and Sync

Control how often certificates are checked and synced:

```nix
roles.provider = {
  settings = {
    # Check daily (default)
    renewalCheckInterval = "daily";
    
    # Or more frequently
    renewalCheckInterval = "hourly";
    
    # Or specific systemd calendar format
    renewalCheckInterval = "*-*-* 00,12:00:00";  # Twice daily at midnight and noon
  };
};
```

### Custom Certificate Settings

Use freeform options to configure advanced ACME settings:

```nix
roles.provider = {
  settings = {
    email = "admin@example.com";
    acceptTerms = true;
    
    # Defaults for all certificates
    defaults = {
      keyType = "ec384";  # Use elliptic curve keys
      extraLegoFlags = [ "--dns.resolvers=1.1.1.1:53" ];
    };
    
    # Use internal ACME server
    server = "https://acme.internal.corp/directory";
    
    # Certificate-specific overrides
    certs."secure.example.com" = {
      keyType = "rsa4096";  # Use RSA for this cert
      extraDomainNames = [ "secure2.example.com" ];
      dnsPropagationCheck = false;  # Skip propagation check
    };
  };
};
```

## Clan Vars Integration

### DNS Provider Credentials

Set up DNS provider credentials:

```bash
# Configure Cloudflare credentials
clan vars generate --generator security-acme-dns

# The generator will prompt for:
# - Cloudflare email
# - Cloudflare API token
```

### Certificate Distribution

Certificates are automatically stored in clan vars when using `shareWildcard` or `certificatesToShare`. They can be accessed at:

```
vars/
├── per-machine/<provider-machine>/
│   └── security-acme-certs/
│       ├── *.example.com.crt
│       ├── *.example.com.key
│       ├── api.example.com.crt
│       └── api.example.com.key
```

### Manual Certificate Sync

To manually trigger certificate sync:

```bash
# On the provider machine
systemctl start sync-acme-certs.service

# Check sync status
systemctl status sync-acme-certs.service
journalctl -u sync-acme-certs.service
```

## Machine Tags

Common machine tags for this service:

- `cert-provider`: Machines that generate certificates
- `web-server`: Machines running web services that need certificates
- `internal-ca`: Machines running internal certificate authorities

## Troubleshooting

### Certificate Not Found on Consumer

1. Check that the provider has generated the certificate:
   ```bash
   ls -la /var/lib/acme/
   ```

2. Check that sync service has run:
   ```bash
   systemctl status sync-acme-certs.service
   ```

3. Verify clan vars contain the certificate:
   ```bash
   clan vars list
   ```

4. On consumer, check certificate setup:
   ```bash
   systemctl status setup-acme-consumer-certs.service
   ```

### DNS Challenge Failures

1. Verify DNS provider credentials:
   ```bash
   clan vars generate --generator security-acme-dns --check
   ```

2. Check ACME service logs:
   ```bash
   journalctl -u acme-*.service
   ```

3. Test DNS propagation:
   ```bash
   dig TXT _acme-challenge.example.com
   ```

### Certificate Permissions Issues

Ensure services have access to certificates:

```nix
# Set appropriate group ownership
certificates.myapp = {
  domain = "*.example.com";
  group = "myapp";  # Service's group
  reloadServices = [ "myapp.service" ];
};
```

## Migration from Traefik ACME

To migrate from Traefik's built-in ACME:

1. Deploy security-acme provider on the same machine as Traefik
2. Generate certificates using security-acme
3. Configure Traefik to use file provider:

```nix
# Disable Traefik ACME
services.traefik.staticConfigOptions.certificatesResolvers = {};

# Use certificates from security-acme
services.traefik.dynamicConfigOptions.tls.certificates = [{
  certFile = config.services.security-acme.consumer.certificates.wildcard.certPath;
  keyFile = config.services.security-acme.consumer.certificates.wildcard.keyPath;
}];
```

## Security Considerations

1. **Clan Vars Encryption**: All certificates in clan vars are encrypted using SOPS
2. **File Permissions**: Certificates are created with restrictive permissions (0640 for certs, 0600 for keys)
3. **Group Access**: Use groups to grant service access to certificates
4. **Renewal**: Automatic renewal happens before expiration (30 days by default)

## Examples

See `inventory/services/security-acme.nix.example` for complete configuration examples.