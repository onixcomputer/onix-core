# Artifacts of the sshd service: Clan's generators openssh, openssh-ca,
# openssh-cert, openssh-rsa and sshd-root-key with their file names, modes
# and scripts (clanServices/sshd/default.nix).
#
# Separate from sshd.ncl because OnixOS gives a module only the public
# artifact values declared by modules evaluated before it, in name order:
# "openssh-keys" sorts before "sshd", which reads the host key, CA key and
# certificate from args.artifacts. Roles, settings and declarations come
# from sshd.ncl; onixos/instances/sshd.ncl gives both instances the same
# settings.
fun onix =>
  let sshd = (import "sshd.ncl") onix in
  ({
    interface = {
      manifest = {
        name = "onix-core/openssh-keys",
        description = "SSH host keys, host CA public key and host certificates of the sshd service.",
        categories = ["ssh", "secrets"],
      },
      portability = {
        status = 'portable,
        requires.typed_namespaces = ["artifacts"],
      },
      roles = sshd.roles,
    },

    impl = fun args => { output.artifacts = sshd.declare_artifacts args },

    tests | not_exported =
      let run = fun role role_settings placement =>
        (
          impl (
            onix.testing.mock_args {
              service = "openssh-keys",
              role_name = role,
              settings = role_settings,
              instance_name = "sshd-keys",
              machine_name = "aspen2",
              placement_facts = placement,
            }
          )
        ).output.artifacts
      in
      let placement = fun server_settings =>
        {
          current = { instance_name = "sshd-keys", role_name = "client", machine_name = "aspen2", machines = ["aspen2"] },
          colocated_roles =
            if server_settings == null then
              []
            else
              [{ instance_name = "sshd-keys", service = "openssh-keys", role_name = "server", machines = ["aspen2"], settings = server_settings, same_machine = true }],
          role_targets = {},
        }
      in
      let server_defaults = interface.roles.server in
      let client_defaults = interface.roles.client in
      let server = run 'server server_defaults (placement null) in
      let extras = run 'server (server_defaults & { host_keys.rsa.enable = true, generate_root_key = true }) (placement null) in
      [
        std.record.fields server == ["openssh", "openssh-ca", "openssh-cert"],
        server.openssh.files."ssh.id_ed25519".secret,
        server.openssh.files."ssh.id_ed25519".mode == "0400",
        server.openssh.files."ssh.id_ed25519".owner == "root",
        !server.openssh.files."ssh.id_ed25519.pub".secret,
        std.string.contains "-f \"$out\"/ssh.id_ed25519" server.openssh.generator_script,
        server.openssh-ca.shared,
        # The CA private key is never an OnixOS file, so it is never deployed.
        std.record.fields server.openssh-ca.files == ["id_ed25519.pub"],
        !(std.record.has_field "generator_script" server.openssh-ca),
        # Per-machine: the certificate names this host.
        !(std.record.has_field "shared" server.openssh-cert),
        std.string.contains "aspen2.clan" server.openssh-cert.description,
        std.record.fields (run 'server (server_defaults & { certificate.enable = false }) (placement null)) == ["openssh"],
        std.string.contains "root@aspen2" extras.sshd-root-key.generator_script,
        extras.openssh-rsa.files."ssh.id_rsa".secret,
        # One declaration per machine: the colocated server owns openssh-ca.
        run 'client client_defaults (placement {}) == {},
        std.record.fields (run 'client client_defaults (placement null)) == ["openssh-ca"],
        std.record.fields (run 'client client_defaults (placement { certificate.enable = false })) == ["openssh-ca"],
        run 'client (client_defaults & { server_certificates = false }) (placement null) == {},
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
