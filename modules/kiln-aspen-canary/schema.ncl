let default_host_uid = 970 in
let default_lattice_uid = 971 in
let default_maximum_requests = 64 in
let default_timeout_milliseconds = 30000 in
{
  default = {
    enable = {
      type = "bool",
      default = false,
      description = "Enable the private Kiln-on-Aspen canary",
    },
    runtimeName = {
      type = "string",
      default = "kiln-aspen-canary",
      description = "Unique systemd, user, socket, and state name stem",
    },
    hostStateDir = {
      type = "string",
      default = "/var/lib/kiln-aspen-canary/host",
      description = "Private Aspen host and Kiln replay state root",
    },
    latticeStateDir = {
      type = "string",
      default = "/var/lib/kiln-aspen-canary/lattice",
      description = "Private Lattice workflow state root",
    },
    hostUid = {
      type = "number",
      default = default_host_uid,
      description = "Stable Unix peer identity for the Aspen host",
    },
    latticeUid = {
      type = "number",
      default = default_lattice_uid,
      description = "Stable Unix identity for the Lattice exchange",
    },
    maximumRequests = {
      type = "number",
      default = default_maximum_requests,
      description = "Finite Aspen host request limit before a clean stop",
    },
    timeoutMilliseconds = {
      type = "number",
      default = default_timeout_milliseconds,
      description = "Unix request deadline in milliseconds",
    },
  },
}
