# Static Server Clan Service

A simple static file server for testing and serving static content.

## Features

- **Simple HTTP server** using Python's built-in server
- **Automatic test page generation** for quick testing
- **Security hardening** with systemd sandboxing
- **Customizable port and directory**
- **Firewall rules automatically configured**

## Usage

### Basic Configuration

```nix
# In your inventory/services/static-server.nix
{
  instances = {
    "static-server-test" = {
      module.name = "static-server";
      module.input = "self";
      roles.server = {
        machines."britton-fw" = { };
        settings = {
          port = 8888;
          directory = "/var/www/test";
          createTestPage = true;
          testPageTitle = "My Test Server";
        };
      };
    };
  };
}
```

### Custom Content

```nix
{
  settings = {
    port = 8080;
    directory = "/var/www/mysite";
    createTestPage = true;
    testPageTitle = "Welcome to My Site";
    testPageContent = ''
      <h2>Additional Information</h2>
      <p>This is custom content that appears on the test page.</p>
      <ul>
        <li>Feature 1</li>
        <li>Feature 2</li>
        <li>Feature 3</li>
      </ul>
    '';
  };
}
```

### Serve Existing Files

```nix
{
  settings = {
    port = 9000;
    directory = "/var/www/production";
    createTestPage = false;  # Don't create index.html
  };
}
```

## How It Works

1. Creates a systemd service that runs Python's HTTP server
2. Optionally generates a test HTML page
3. Serves all files from the configured directory
4. Runs as `nobody` user for security
5. Automatically restarts if it crashes

## Combining with Tailscale-Traefik

This service works great with the `tailscale-traefik` module:

```nix
# Configure static-server
clan.services.static-server.server = {
  port = 8888;
  testPageTitle = "Tailscale-Traefik Test";
};

# Configure tailscale-traefik to proxy to it
clan.services.tailscale-traefik.server = {
  services = {
    test = {
      port = 8888;
      subdomain = "test";
    };
  };
};
```

## Security

The service runs with minimal privileges:
- Runs as `nobody:nogroup`
- Sandboxed with systemd security features
- Can only write to its configured directory
- No access to home directories or system files