fun onix =>
  let host_impl = fun args =>
    let p = args.package_paths in
    let ld_target = m%"%{p."nix-ld"}/libexec/nix-ld"% in
    {
      output.host = {
        # nixpkgs' nix-ld module supplies this exact buildEnv output from the
        # configured programs.nix-ld.libraries list. Keep it intact rather
        # than rebuilding a second library tree here.
        packages = [p."nix-ld", p."nix-ld-libraries", p.envfs],
        kernel.modules = ["fuse"],
        environment = {
          NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so",
          NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib",
        },
        files."fish/conf.d/onixos-fhs-compat.fish".text = m%"
          # Fish does not read /etc/profile; export the nix-ld session settings
          # from its system configuration as well.
          set -gx NIX_LD /run/current-system/sw/share/nix-ld/lib/ld.so
          set -gx NIX_LD_LIBRARY_PATH /run/current-system/sw/share/nix-ld/lib
        "%,
        units = {
          "usr-bin.mount" = {
            sections = {
              Unit = {
                Description = "FHS-compatible /usr/bin via envfs",
                DefaultDependencies = "no",
                After = "local-fs.target",
                Conflicts = "umount.target",
                Before = "umount.target",
              },
              Mount = {
                What = "none",
                Where = "/usr/bin",
                Type = "envfs",
                Options = "bind-mount=/bin,fallback-path=%{p."envfs-fallback-path"}",
              },
            },
            wanted_by = ["local-fs.target"],
          },
          "bin.mount" = {
            sections = {
              Unit = {
                Description = "Bind /bin to envfs-backed /usr/bin",
                DefaultDependencies = "no",
                After = ["local-fs.target", "usr-bin.mount"],
                Conflicts = "umount.target",
                Before = "umount.target",
                Requires = "usr-bin.mount",
              },
              Mount = {
                What = "/usr/bin",
                Where = "/bin",
                Type = "none",
                Options = "bind",
              },
            },
            wanted_by = ["local-fs.target"],
          },
        },
        # nix-ld's pinned package writes the host-platform interpreter path to
        # nix-support/ldpath. Adopt only that path; don't replace an unrelated
        # file or symlink already occupying the kernel's interpreter location.
        activation."nix-ld-interpreter" = m%"
          ldpath=$(%{p.coreutils}/bin/cat %{p."nix-ld"}/nix-support/ldpath)
          target=%{ld_target}
          if [ -z "$ldpath" ]; then
            echo "fhs-compat: nix-ld package has an empty nix-support/ldpath" >&2
            exit 1
          fi
          target_real=$(%{p.coreutils}/bin/readlink -f "$target")
          if [ -L "$ldpath" ]; then
            current_real=$(%{p.coreutils}/bin/readlink -f "$ldpath" 2>/dev/null || true)
            if [ "$current_real" = "$target_real" ]; then
              :
            else
              current=$(%{p.coreutils}/bin/readlink "$ldpath")
              case "$current" in
                /nix/store/*-nix-ld-*/libexec/nix-ld) ;;
                *)
                  echo "fhs-compat: refusing to replace conflicting interpreter path $ldpath -> $current" >&2
                  exit 1
                  ;;
              esac
              tmp="$ldpath.onixos.$$"
              %{p.coreutils}/bin/ln -s "$target" "$tmp"
              %{p.coreutils}/bin/mv -Tf "$tmp" "$ldpath"
            fi
          elif [ -e "$ldpath" ]; then
            echo "fhs-compat: refusing to replace non-symlink interpreter path $ldpath" >&2
            exit 1
          else
            %{p.coreutils}/bin/mkdir -p "$(%{p.coreutils}/bin/dirname "$ldpath")"
            tmp="$ldpath.onixos.$$"
            %{p.coreutils}/bin/ln -s "$target" "$tmp"
            %{p.coreutils}/bin/mv -Tf "$tmp" "$ldpath"
          fi
        "%,
      },
    }
  in
  ({
    interface = {
      manifest = {
        name = "onix-core/fhs-compat",
        description = "Pinned nix-ld and envfs runtime support for unpatched ELF binaries and FHS shebangs on OnixOS systemd hosts.",
        categories = ["system", "runtime"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [
          {
            namespace = "host",
            targets = ["onixos"],
            rationale = "NixOS systems retain the source configuration in inventory/tags/common/fhs-compat.nix.",
          },
        ],
      },
      packages = ["coreutils", "nix-ld", "nix-ld-libraries", "envfs", "envfs-fallback-path"],
      roles.host = {},
    },
    impl = host_impl,
  }
  ) | onix.ServiceModule
