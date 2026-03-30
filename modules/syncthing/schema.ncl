{
  peer = {
    user = { type = "string", default = "brittonr", description = "User to run Syncthing as" },
    group = { type = "string", default = "users", description = "Group to run Syncthing as" },
    dataDir = { type = "string", default = "/home/brittonr", description = "Syncthing data directory" },
    guiPort = { type = "port", default = 8384, description = "Syncthing web GUI port" },
    listenPort = { type = "port", default = 22000, description = "Syncthing listen port" },
    openFirewall = { type = "bool", default = true, description = "Open firewall ports for Syncthing" },
    guiAddress = { type = "string", default = "127.0.0.1:8384", description = "Address for the web GUI" },
  },
}
