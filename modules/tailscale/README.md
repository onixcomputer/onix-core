---
description = "Manages Tailscale VPN service"
categories = ["Network", "System"]
features = ["inventory"]
---
# Tailscale
This module manages the [Tailscale](https://tailscale.com/) VPN service, allowing easy connection to your Tailscale network.
## Overview
Tailscale is a zero-config VPN that creates a secure network between your devices. It works by establishing direct connections between devices when possible, and relays through their servers when not.
## Role
### Default
The default role installs and configures Tailscale with all features available.
## Configuration Options
The following configuration options are available:
- `port`: The port to listen on for tunnel traffic (default: 41641).
- `openFirewall`: Whether to open the firewall for the specified port (default: true).
- `useExitNode`: Whether to configure this node to use an exit node (default: false).
- `exitNodeName`: The hostname of the exit node to use if useExitNode is true (default: "").
- `allowLanAccess`: Allow access to the local network when using an exit node (default: true).
- `advertiseRoutes`: List of CIDR prefixes to advertise for subnet routing (default: []).
- `extraUpFlags`: Extra flags to pass to `tailscale up` (default: []).
## Examples
### Basic Client
```nix
inventory.services.tailscale.mynetwork = {
  roles.default.machines = [ "laptop" "desktop" ];
};
```
### Exit Node
```nix
inventory.services.tailscale.mynetwork = {
  roles.default.machines = [ "server" ];
  roles.default.config = {
    useExitNode = true;
    exitNodeName = "exit-node.example";
  };
};
```
### Subnet Router
```nix
inventory.services.tailscale.mynetwork = {
  roles.default.machines = [ "router" ];
  roles.default.config = {
    advertiseRoutes = [ "192.168.1.0/24" ];
    extraUpFlags = [ "--advertise-routes" ];
  };
};
```
