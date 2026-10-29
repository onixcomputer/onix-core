# Clan instance sshd (inventory/services/services.ncl:409-418): server and
# client on every NixOS machine; the client also trusts *.local. sshd-keys
# declares the same instance's artifacts (see onixos/services/openssh-keys.ncl)
# and must keep the same role settings.
let server_role = { tags = ["nixos"], settings = {} } in
let client_role = { tags = ["nixos"], settings = { certificate.search_domains = ["local"] } } in
{
  sshd = { service = "sshd", roles = { server = server_role, client = client_role } },
  sshd-keys = { service = "openssh-keys", roles = { server = server_role, client = client_role } },
}
