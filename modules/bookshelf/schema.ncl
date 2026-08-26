let default_port = 3000 in
let default_restart_delay_seconds = 5 in
{
  server = {
    sourceDir = { type = "string", default = "/var/lib/bookshelf/source", description = "Private directory that receives operator-owned EPUB and PDF source files" },
    libraryDir = { type = "string", default = "/var/lib/bookshelf/library", description = "Private generated library, profile, and reading-position directory" },
    bindAddress = { type = "string", default = "127.0.0.1", description = "Explicit private address for the Bookshelf HTTP listener" },
    port = { type = "port", default = default_port, description = "Private Bookshelf HTTP listener port" },
    siteUrl = { type = "string", default = "http://127.0.0.1:3000", description = "Canonical URL used in Bookshelf links and OPDS output" },
    readOnly = { type = "bool", default = false, description = "Disable profile and reading-position writes when true" },
    openFirewall = { type = "bool", default = false, description = "Admit the HTTP listener through the NixOS firewall" },
    firewallInterface = { type = "nullable_string", default = "tailscale0", description = "Private interface that may admit the Bookshelf listener" },
    restartDelaySeconds = { type = "number", default = default_restart_delay_seconds, description = "Systemd restart delay after an application failure" },
  },
}
