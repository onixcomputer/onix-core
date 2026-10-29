# Clan instance br-tailnet (inventory/services/services.ncl). Clan also
# targets tag dgx-spark, which no inventory machine carries (the DGX Sparks
# set up Tailscale through modules/dgx-machine). OnixOS rejects tags without
# machines, so only tailnet-brittonr is listed: the selected machines are the same.
{
  br-tailnet = {
    service = "tailscale",
    roles.peer = {
      tags = ["tailnet-brittonr"],
      settings = {
        enable_ssh = true,
        exit_node = false,
        enable_host_aliases = true,
      },
    },
  },
}
