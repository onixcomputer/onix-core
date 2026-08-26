let sc = import "../settings-contracts.ncl" in
let default_port = 39300 in
let default_restart_delay_seconds = 5 in
let invalid_port = 70000 in
let test_address = "100.110.43.11" in
{
  positive =
    sc.validate_fields
      "bookshelf:server"
      "bookshelf-positive"
      {
        sourceDir = "/datapool/bookshelf/source",
        libraryDir = "/datapool/bookshelf/library",
        bindAddress = test_address,
        port = default_port,
        siteUrl = "http://%{test_address}:%{default_port}",
        readOnly = false,
        openFirewall = true,
        firewallInterface = "tailscale0",
        restartDelaySeconds = default_restart_delay_seconds,
      },
  negative =
    sc.validate_fields
      "bookshelf:server"
      "bookshelf-negative"
      {
        sourceDir = false,
        libraryDir = [],
        bindAddress = 0,
        port = invalid_port,
        siteUrl = {},
        readOnly = "no",
        openFirewall = "yes",
        firewallInterface = [],
        restartDelaySeconds = "restart",
      },
}
