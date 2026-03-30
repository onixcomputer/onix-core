# adminTokenFile is config-dependent (generated secret path) — stays in Nix.
{
  server = {
    DOMAIN = { type = "string", default = "https://vaultwarden.localhost", description = "Vaultwarden domain" },
    ROCKET_PORT = { type = "port", default = 8222, description = "Rocket web server port" },
    WEBSOCKET_ENABLED = { type = "bool", default = true, description = "Enable WebSocket notifications" },
    WEBSOCKET_PORT = { type = "port", default = 3012, description = "WebSocket port" },
    SIGNUPS_ALLOWED = { type = "bool", default = false, description = "Allow new user signups" },
    INVITATIONS_ALLOWED = { type = "bool", default = true, description = "Allow email invitations" },
    SHOW_PASSWORD_HINT = { type = "bool", default = false, description = "Show password hints" },
  },
}
