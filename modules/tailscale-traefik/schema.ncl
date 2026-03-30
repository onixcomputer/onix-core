# externalInterface is config-dependent — stays in Nix.
# services uses NixOS submodule — typed as record, validated at build time.
{
  server = {
    domain = { type = "string", description = "Root domain for services" },
    email = { type = "string", description = "ACME email for certificate requests" },
    services = { type = "record", default = {}, description = "Service definitions (submodule per service)" },
    additionalSubdomains = { type = "array_string", default = [], description = "Extra subdomains for the ACME cert" },
    traefikDashboard = { type = "bool", default = true, description = "Enable Traefik dashboard" },
    sslRedirect = { type = "bool", default = true, description = "Redirect HTTP to HTTPS" },
    ddclientInterval = { type = "number", default = 300, description = "DNS update interval (seconds)" },
    dnsPropagationCheck = { type = "bool", default = true, description = "Check DNS propagation before ACME" },
    dnsResolvers = { type = "array_string", default = [], description = "DNS resolvers for ACME challenges" },
    dnsPropagationDelay = { type = "number", default = 0, description = "Seconds to wait before DNS propagation check" },
    securityHeaders = { type = "bool", default = true, description = "Add security headers middleware" },
    tailscaleSSH = { type = "bool", default = false, description = "Enable Tailscale SSH" },
    tailscaleExitNode = { type = "bool", default = false, description = "Advertise as exit node" },
    tailscalePort = { type = "port", default = 41641, description = "Tailscale UDP port" },
    tailscaleAuthKeyFile = { type = "nullable_string", default = null, description = "Path to Tailscale auth key file" },
    extraTraefikConfig = { type = "record", default = {}, description = "Extra Traefik static config" },
    extraDynamicConfig = { type = "record", default = {}, description = "Extra Traefik dynamic config" },
  },
}
