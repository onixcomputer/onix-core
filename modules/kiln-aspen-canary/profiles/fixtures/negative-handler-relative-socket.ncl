let make_profile = import "../lattice-handler-profile.ncl" in
make_profile {
  host_uid = 970,
  socket_path = "run/kiln-aspen-canary/lattice.sock",
}
