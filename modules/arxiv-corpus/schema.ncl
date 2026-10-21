{
  server = {
    host = { type = "string", default = "127.0.0.1", description = "Loopback or Tailscale IPv4 bind address" },
    port = { type = "port", default = 7998, description = "Private JSON API port" },
    revision = { type = "string", default = "cee894837962fede5612cccf2a4c7cacf49b4c3a", description = "Immutable Hugging Face resource commit" },
  },
}
