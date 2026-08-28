let make_profile = import "../lattice-handler-profile.ncl" in
make_profile {
  host_uid = 974,
  socket_path = "/run/kiln-aspen-ci/internal/lattice.sock",
  maximum_connections = 65536,
  workflow_revision = "b3:not-a-blake3-identity",
}
