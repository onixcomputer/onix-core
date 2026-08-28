let make_profile = import "../radicle-profile.ncl" in
let maximum_provider_polls = 64 in
make_profile {
  host_uid = 0,
  socket_path = "/run/kiln-aspen-canary/lattice.sock",
  replay_database_path = "/var/lib/kiln-aspen-canary/host/replay.sqlite",
  maximum_polls = maximum_provider_polls,
}
