{
  server = {
    enable = { type = "bool", default = true, description = "Enable the homepage dashboard" },
    listenPort = { type = "port", default = 8082, description = "Port for the homepage dashboard" },
    openFirewall = { type = "bool", default = true, description = "Open firewall port" },
    allowedHosts = { type = "string", default = "", description = "Allowed hosts header value" },
    settings = { type = "record", default = { title = "Dashboard", background = { image = "", blur = "sm", saturate = 50, brightness = 50, opacity = 50 } }, description = "Homepage dashboard settings" },
    services = { type = "array", default = [], description = "Service definitions" },
    widgets = { type = "array", default = [], description = "Widget configurations" },
    bookmarks = { type = "array", default = [], description = "Bookmark definitions" },
  },
}
