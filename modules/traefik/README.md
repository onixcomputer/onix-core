# Traefik Clan Service Module

This module provides a Traefik reverse proxy service with clan-specific conveniences for easy integration with other services.

## Features

- **Automatic TLS/HTTPS**: Built-in Let's Encrypt and Tailscale certificate support
- **Service Discovery**: Easy routing configuration for clan services
- **Authentication**: Support for Basic Auth and Tailscale authentication
- **Conditional Integration**: Other clan services can automatically use Traefik when available
- **Security Defaults**: Security headers middleware enabled by default

## Configuration Options

### Basic Configuration

```nix
{
  enableAutoTLS = true;
  acmeEmail = "admin@example.com";
  certificateResolver = "letsencrypt"; # or "tailscale"
  
  enableDashboard = true;
  dashboardHost = "traefik.example.com";
  dashboardAuth = "basic";
  
  services = [
    {
      name = "grafana";
      host = "grafana.example.com";
      backend = "http://localhost:3000";
      enableAuth = false;
      middlewares = [ ];
    }
  ];
}
```

### Authentication Types

#### Basic Authentication
```nix
services = [
  {
    name = "myapp";
    host = "myapp.example.com";
    backend = "http://localhost:8080";
    enableAuth = true;
    # Default authType is "basic"
  }
];
```

When enabled, you'll be prompted for a password during deployment.

#### Tailscale Authentication
```nix
services = [
  {
    name = "internal-app";
    host = "app.example.com";
    backend = "http://localhost:8080";
    enableAuth = true;
    authType = "tailscale";
    tailscaleDomain = "company.ts.net";
  }
];
```

This uses the Tailscale connectivity plugin to verify users are on your tailnet.

### Certificate Resolvers

#### Let's Encrypt (Default)
```nix
certificateResolver = "letsencrypt";
acmeEmail = "admin@example.com"; # Required
```

#### Tailscale Certificates
```nix
certificateResolver = "tailscale";
# No email needed - uses Tailscale's built-in certificates
```

**DNS Resolution for Service Subdomains**: When using custom subdomains (e.g., `grafana.your-tailnet.ts.net`) that differ from your machine's Tailscale name:

1. **Traefik automatically requests certificates** for any subdomain under your tailnet
2. **DNS must resolve correctly** - options include:
   - Configure DNS aliases in Tailscale admin console
   - Add local DNS entries (e.g., `/etc/hosts`)
   - Use the machine's actual Tailscale hostname
   - Set up split-horizon DNS for `*.your-tailnet.ts.net`

### Routing with Tailscale

When using Tailscale certificates with service-specific subdomains, you'll need to ensure DNS resolves correctly. For example, if your machine is `server1.your-tailnet.ts.net` but you want to access Grafana at `grafana.your-tailnet.ts.net`:

**Options for DNS resolution:**
1. **Configure DNS aliases in Tailscale admin console** (recommended)
2. **Add entries to `/etc/hosts`** on client machines
3. **Use the machine's actual Tailscale hostname** instead of service-specific subdomains
4. **Set up a local DNS server** for your tailnet

## Service Integration

Other clan services can automatically integrate with Traefik when it's available on the same machine.

### For Service Authors

1. Import the Traefik lib:
```nix
traefikLib = import ../traefik/lib.nix { inherit lib; };
```

2. Add Traefik options to your service:
```nix
options = {
  # Your service options...
  traefik = traefikLib.mkTraefikOptions;
};
```

3. Use the integration helper:
```nix
services.traefik = traefikLib.mkTraefikIntegration {
  serviceName = "myservice";
  servicePort = 8080;
  traefikConfig = settings.traefik;
  config = config;
};
```

4. Add auth generator if needed:
```nix
(lib.mkIf (traefikLib.needsTraefikAuth { serviceName = "myservice"; inherit config; })
  (traefikLib.mkTraefikAuthGenerator { serviceName = "myservice"; inherit pkgs; })
)
```

### For Service Users

Configure Traefik integration in your service settings:
```nix
services.grafana.server.settings = {
  # Grafana settings...
  
  traefik = {
    enable = true;
    host = "grafana.example.com";
    enableAuth = true;
    authType = "tailscale";
    tailscaleDomain = "company.ts.net";
  };
};
```

## Advanced Configuration

### Custom Middlewares
```nix
dynamicConfigOptions = {
  http.middlewares = {
    rate-limit = {
      rateLimit = {
        average = 100;
        burst = 200;
      };
    };
  };
};
```

### Custom TLS Options
```nix
dynamicConfigOptions = {
  tls.options = {
    default = {
      minVersion = "VersionTLS12";
      cipherSuites = [
        "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
        "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
      ];
    };
  };
};
```

## Deployment

1. Add the Traefik service to your inventory
2. Tag machines that should run Traefik with `proxy` and `loadbalancer`
3. Deploy with clan

The service will automatically:
- Configure firewall rules for ports 80 and 443
- Set up certificate renewal
- Create necessary directories
- Generate authentication secrets as needed