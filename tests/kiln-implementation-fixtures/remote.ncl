# Explicit local-only Git fixture transport; never an alternate live remote.
{
  remote_name | String = "origin",
  remote_url | String = "/var/lib/kiln-implementation/github/remote.git",
  transport | [| 'local_bare_fixture |] = 'local_bare_fixture,
}
