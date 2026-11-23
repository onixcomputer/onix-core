# Shared Berkeley Mono font tarball artifact.
#
# The NixOS tag installs the artifact through clan-vars-compat.nix. The host
# leaf installs it directly and makes the directory visible to fontconfig.
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
      packages = ["bash", "coreutils", "gnutar", "gzip", "fontconfig", "fontconfig-data=fontconfig.out"],
      roles.default = {},
    },

    impl = fun args =>
      # The artifact file's default placement, decrypted at activation.
      let font = "/run/artifacts/berkeley-mono-font/font_data" in
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
          }
          # inventory/tags/common/berkeley-mono-font.nix: extract the decrypted
          # tarball into a directory fontconfig searches, every boot.
          & {
            host = {
              packages = [args.package_paths.fontconfig, args.package_paths."fontconfig-data"],
              # The bin output has no configuration. The stock fonts.conf reads
              # /etc/fonts/conf.d even when applications use its store path.
              files."fonts/fonts.conf".link = "%{args.package_paths."fontconfig-data"}/etc/fonts/fonts.conf",
              files."fonts/conf.d/10-berkeley-mono.conf".text = m%"
                <?xml version="1.0"?>
                <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
                <fontconfig>
                  <include>%{args.package_paths."fontconfig-data"}/etc/fonts/conf.d</include>
                  <dir>/var/lib/fonts/berkeley-mono</dir>
                </fontconfig>
              "%,
              units."berkeley-mono-font-install.service" = {
                sections = {
                  Unit = {
                    Description = "Install Berkeley Mono font from the decrypted artifact",
                    ConditionPathExists = font,
                  },
                  Service = {
                    Type = "oneshot",
                    RemainAfterExit = "yes",
                    ExecStart = "%{args.package_paths.bash}/bin/bash -eu -c '%{args.package_paths.coreutils}/bin/mkdir -p /var/lib/fonts/berkeley-mono && %{args.package_paths.gnutar}/bin/tar --use-compress-program=%{args.package_paths.gzip}/bin/gzip -xf %{font} -C /var/lib/fonts/berkeley-mono'",
                  },
                },
                wanted_by = ["multi-user.target"],
              },
            },
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
