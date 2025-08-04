# Tailscale + Traefik Clan Service

This clan service provides a complete solution for exposing services via Tailscale with automatic SSL certificates and DNS management.

## Features

- **Tailscale-only access**: Services are only accessible when connected to your Tailscale network (default)
- **Public mode option**: Expose services to the internet using your public IP (requires port forwarding)
- **Automatic SSL certificates**: Let's Encrypt certificates via DNS challenge (works with private IPs!)
- **Dynamic DNS updates**: Automatically updates Cloudflare DNS with your Tailscale IP or public IP
- **Service discovery**: Easy configuration for multiple services
- **Automatic port detection**: Automatically detects ports for common services (homepage, grafana, vaultwarden, etc.)
- **Security by default**: Firewall rules restrict access to Tailscale interface only (unless publicMode is enabled)

## Usage

### Basic Configuration

```nix
{
  clan.services.tailscale-traefik.server = {
    domain = "onix.computer";
    email = "admin@example.com";
    
    services = {
      grafana = {
        port = 3000;
      };
      vaultwarden = {
        port = 8080;
      };
      nextcloud = {
        port = 8081;
      };
      # Port auto-detection for homepage service
      homepage = {
        # No port needed - automatically detects from homepage-dashboard service
      };
    };
  };
}
```

This will:
- Configure Tailscale on the machine
- Set up ddclient to update DNS records for each service
- Configure Traefik to handle SSL and routing
- Create URLs like `https://grafana.onix.computer` (accessible only via Tailscale)

### Advanced Configuration

```nix
{
  clan.services.tailscale-traefik.server = {
    domain = "onix.computer";
    email = "admin@example.com";
    
    # Enable Tailscale exit node
    tailscaleExitNode = true;
    tailscaleSSH = true;
    
    # Customize ddclient update interval (seconds)
    ddclientInterval = 600;
    
    # Services with custom configuration
    services = {
      grafana = {
        port = 3000;
        middlewares = [ "security-headers" ];
      };
      
      # Custom subdomain
      bitwarden = {
        port = 8080;
        subdomain = "vaultwarden";
      };
      
      # Service with extra Traefik config
      nextcloud = {
        port = 8081;
        extraRouterConfig = {
          priority = 100;
        };
        extraServiceConfig = {
          loadBalancer.sticky.cookie = {
            name = "nextcloud_sticky";
            secure = true;
            httpOnly = true;
          };
        };
      };
      
      # Custom service with portPath for auto-detection
      myapp = {
        portPath = "services.myapp.config.listenPort";
        # Port will be auto-detected from the specified config path
      };
    };
    
    # Additional subdomains (without services)
    additionalSubdomains = [ "api" "cdn" ];
    
    # Disable Traefik dashboard
    traefikDashboard = false;
    
    # Extra Traefik configuration
    extraTraefikConfig = {
      log.level = "DEBUG";
      accessLog.format = "json";
    };
    
    # Extra dynamic configuration
    extraDynamicConfig = {
      http.middlewares.custom-auth = {
        basicAuth.users = [ "user:$2y$10$..." ];
      };
    };
  };
}
```

### Public Mode Configuration

To expose services publicly to the internet instead of only via Tailscale:

```nix
{
  clan.services.tailscale-traefik.server = {
    publicMode = true;  # Use public IP instead of Tailscale IP
    domain = "example.com";
    email = "admin@example.com";
    
    services = {
      website = {
        port = 8080;
        subdomain = "www";  # Accessible at www.example.com
      };
      blog = {
        port = 3000;
        # Accessible at blog.example.com
      };
    };
  };
}
```

**Public Mode Requirements:**
- Port forwarding on your router (80 → machine:80, 443 → machine:443)
- ISP that allows incoming connections
- Static IP or dynamic DNS (handled automatically)

## Required Secrets

The service requires the following secrets to be configured on each machine:

1. **Cloudflare API Token**
   - Used for both DNS updates (ddclient) and Let's Encrypt DNS challenges (Traefik)
   - Required permissions: `Zone:Zone:Read` and `Zone:DNS:Edit`
   - Only needs to be entered once!

2. **Cloudflare Email**
   - Your Cloudflare account email

3. **Tailscale Auth Key**
   - Pre-authentication key from Tailscale admin panel
   - Can be reusable or single-use

### Setting up secrets

For each machine that will run the service:
```bash
# On britton-desktop
clan vars generate --machine britton-desktop tailscale-traefik

# On britton-fw
clan vars generate --machine britton-fw tailscale-traefik
```

Note: Each machine needs its own secrets configuration. This allows using different Tailscale auth keys per machine if needed.

## How It Works

1. **Tailscale** connects your machine to your private network
2. **ddclient** updates Cloudflare DNS records to point to your Tailscale IP
3. **Traefik** handles incoming requests:
   - Terminates SSL using Let's Encrypt certificates
   - Routes to appropriate backend services
   - Obtains certificates via DNS challenge (no public access needed!)
4. **Services** run on localhost and are proxied by Traefik

## Security

- Services are **only** accessible via Tailscale network
- Firewall blocks all external access to ports 80/443
- Services bind to localhost only
- SSL certificates are properly validated

## Troubleshooting

### Check Tailscale connection
```bash
tailscale status
tailscale ip -4
```

### Check DNS updates
```bash
dig grafana.onix.computer
systemctl status ddclient
journalctl -u ddclient -f
```

### Check Traefik
```bash
systemctl status traefik
journalctl -u traefik -f
# Access dashboard at https://traefik.yourdomain.com
```

### Common Issues

- **Certificate errors**: Check Cloudflare API token permissions
- **DNS not updating**: Ensure ddclient can reach Tailscale (`systemctl restart ddclient`)
- **Service unreachable**: Verify service is running on the configured port