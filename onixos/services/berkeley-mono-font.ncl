# Shared Berkeley Mono font tarball artifact.
#
# Carried over from Clan's shared berkeley-mono-font generator. Until the
# tag is ported, inventory/tags/common/berkeley-mono-font.nix still installs
# the font and reads this file through onixos/nix/clan-vars-compat.nix.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/berkeley-mono-font",
        description = "Licensed Berkeley Mono font tarball shared by every machine.",
        categories = ["fonts", "secrets"],
      },
      portability = {
        status = 'portable,
        requires.typed_namespaces = ["artifacts"],
      },
      roles.default = {},
    },

    impl = fun _args =>
      {
        output =
          onix.artifact_declaration {
            name = "berkeley-mono-font",
            shared = true,
            # The install unit reads the tarball as an unprivileged step.
            files.font_data = onix.artifact_file { mode = "0444" },
            prompts.font_tarball_path.description = "Absolute path to Berkeley Mono font tarball (.tar.gz)",
            generator_script = m%"
              TARBALL=$(cat "$prompts"/font_tarball_path)
              if [ ! -f "$TARBALL" ]; then
                echo "Error: Font tarball not found: $TARBALL" >&2
                exit 1
              fi
              cp "$TARBALL" "$out"/font_data
            "%,
            description = "Berkeley Mono font tarball",
          },
      },

    tests | not_exported =
      let mock =
        onix.testing.mock_args {
          service = "berkeley-mono-font",
          role_name = 'default,
          settings = interface.roles.default,
        }
      in
      let artifact = (impl mock).output.artifacts.berkeley-mono-font in
      [
        artifact.shared,
        artifact.files.font_data.secret,
        artifact.files.font_data.mode == "0444",
      ]
      |> std.test.assert_all,
  }
  ) | onix.ServiceModule
