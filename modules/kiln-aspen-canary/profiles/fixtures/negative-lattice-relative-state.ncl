let make_config = import "../lattice-config.ncl" in
make_config {
  data_dir = "var/lib/kiln-aspen-canary/lattice",
  shell = "/run/current-system/sw/bin/sh",
}
