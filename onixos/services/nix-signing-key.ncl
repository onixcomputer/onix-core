# Nix store signing key artifact for each NixOS machine.
#
# Carried over from Clan's nix-signing-key generator. Until the nix-signing
# tag is ported, inventory/tags/common/nix-signing.nix still sets
# nix.settings.secret-key-files and reads this key through
# onixos/nix/clan-vars-compat.nix. File names match Clan's, so existing keys
# move without re-encryption.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/nix-signing-key",
        description = "Per-machine Nix store signing key pair.",
        categories = ["nix", "secrets"],
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
            name = "nix-signing-key",
            files = {
              key = onix.artifact_file {},
              "key.pub" = onix.artifact_file { secret = false },
            },
            generator_script = m%"
              nix --extra-experimental-features "nix-command flakes" \
                key generate-secret --key-name %{args.machine_name}-1 > "$out/key"
              nix --extra-experimental-features "nix-command flakes" \
                key convert-secret-to-public < "$out/key" > "$out/key.pub"
            "%,
            description = "Nix store signing key for %{args.machine_name}",
          },
      },

    tests | not_exported =
      let mock =
        onix.testing.mock_args {
          service = "nix-signing-key",
          role_name = 'default,
          settings = interface.roles.default,
          machine_name = "aspen2",
        }
      in
      let artifact = (impl mock).output.artifacts.nix-signing-key in
      [
        artifact.files.key.secret,
        artifact.files.key.mode == "0400",
        !artifact.files."key.pub".secret,
        # Machines trust each other's keys by the Clan-era name <host>-1.
        std.string.contains "--key-name aspen2-1" artifact.generator_script,
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
