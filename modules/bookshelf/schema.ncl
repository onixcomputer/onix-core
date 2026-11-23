let default_port = 3000 in
let default_restart_delay_seconds = 5 in
let default_intake_port = 3001 in
let default_intake_max_megabytes = 256 in
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
    intakeEnable = { type = "bool", default = false, description = "Accept EPUB and PDF uploads over HTTP from untagged devices of this machine's Tailscale owner" },
    intakePort = { type = "port", default = default_intake_port, description = "Upload endpoint port on bindAddress" },
    intakeMaxMegabytes = { type = "number", default = default_intake_max_megabytes, description = "Largest accepted upload in MiB" },
    intakeCalibreUrl = { type = "nullable_string", default = null, description = "Loopback Calibre content server that also receives uploads" },
    intakeCalibreLibraryId = { type = "nullable_string", default = null, description = "Calibre library id that receives uploads; null uses the server's default library" },
    intakeCalibreSourceAddress = { type = "nullable_string", default = null, description = "Dedicated loopback source address that the Calibre server trusts for writes" },
  },
}
