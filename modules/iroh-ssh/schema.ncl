let default_ssh_port = 22 in
{
  peer = {
    sshPort = { type = "port", default = default_ssh_port, description = "Local SSH port iroh-ssh forwards incoming connections to" },
  },
}
