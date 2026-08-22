{
  server = {
    port = { type = "port", default = 4433, description = "Server port" },
    bindAddress = { type = "string", default = "127.0.0.1", description = "Address to bind to" },
    openFirewall = { type = "bool", default = false, description = "Open the server port in the firewall" },
    dataDir = { type = "nullable_string", default = null, description = "Data directory (null uses the systemd StateDirectory)" },
  },
}
