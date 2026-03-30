# tunnelName defaults to config.networking.hostName — stays in Nix.
{
  default = {
    tunnelName = { type = "nullable_string", default = null, description = "Cloudflare tunnel name (defaults to machine hostname)" },
    ingress = { type = "record", default = {}, description = "Ingress rules mapping hostnames to backend services" },
  },
}
