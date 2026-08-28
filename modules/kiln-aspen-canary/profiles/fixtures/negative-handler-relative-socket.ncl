let make_profile = import "../lattice-handler-profile.ncl" in
let host_uid = 970 in
let maximum_host_requests = 64 in
let maximum_provider_polls = 64 in
let dispatch_connections_per_effect = 1 in
let maximum_connections =
  maximum_host_requests * (maximum_provider_polls + dispatch_connections_per_effect)
in
make_profile {
  host_uid,
  socket_path = "run/kiln-aspen-canary/lattice.sock",
  maximum_connections,
}
