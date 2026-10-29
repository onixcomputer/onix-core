# SSH key pair a machine uses to reach its remote Nix builders.
#
# Carried over from Clan's nix-builder-ssh generator. Until the
# remote-builders tag is ported, inventory/tags/remote-builders.nix still
# configures the builders and reads this key through
# onixos/nix/clan-vars-compat.nix. Every machine's public key is also read
# from vars/ by inventory/tags/common/shared-users.nix.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/nix-builder-ssh",
        description = "Per-machine SSH key pair for remote Nix builds.",
        categories = ["nix", "ssh", "secrets"],
      },
      portability = {
        status = 'portable,
        requires.typed_namespaces = ["artifacts"],
      },
      roles.default = {},
    },

    impl = fun args =>
      {
        output =
          onix.artifact_declaration {
            name = "nix-builder-ssh",
            files = {
              id_ed25519 = onix.artifact_file {},
              "id_ed25519.pub" = onix.artifact_file { secret = false },
            },
            generator_script = m%"
              ssh-keygen -t ed25519 -N "" -C "nix-builder@%{args.machine_name}" -f "$out/id_ed25519"
            "%,
            description = "Remote-build SSH key for %{args.machine_name}",
          },
      },

    tests | not_exported =
      let mock =
        onix.testing.mock_args {
          service = "nix-builder-ssh",
          role_name = 'default,
          settings = interface.roles.default,
          machine_name = "aspen2",
        }
      in
      let artifact = (impl mock).output.artifacts.nix-builder-ssh in
      [
        artifact.files.id_ed25519.secret,
        !artifact.files."id_ed25519.pub".secret,
        std.string.contains "nix-builder@aspen2" artifact.generator_script,
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
