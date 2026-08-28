let make_profile = import "../lattice-handler-profile.ncl" in
let maximum_connection_count = 65536 in
let overbound_connection_count = maximum_connection_count + 1 in
let host_uid = 970 in
make_profile {
  host_uid,
  socket_path = "/run/kiln-aspen-canary/lattice.sock",
  maximum_connections = overbound_connection_count,
}
