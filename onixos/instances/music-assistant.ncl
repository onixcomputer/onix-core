# machines/aspen2/configuration.nix: services.music-assistant.enable = true.
{
  music-assistant = {
    service = "music-assistant",
    roles.host = { machines = ["aspen2"], settings = {} },
  },
}
