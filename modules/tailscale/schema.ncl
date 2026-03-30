# authKeyFile and externalInterface are config-dependent — stay in Nix.
{
  peer = {
    enableSSH = { type = "bool", default = false, description = "Enable Tailscale SSH" },
    exitNode = { type = "bool", default = false, description = "Advertise as exit node" },
    enableHostAliases = { type = "bool", default = true, description = "Sync Tailscale device names to /etc/hosts" },
    extraUpFlags = { type = "array_string", default = [], description = "Extra flags passed to tailscale up" },
  },
}
