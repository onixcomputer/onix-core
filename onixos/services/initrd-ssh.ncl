# Public-key recovery before the real root filesystem can be mounted.
fun onix =>
  ({
    interface = {
      manifest = {
        name = "onix-core/initrd-ssh",
        description = "Private install-time host identity and public-key SSH recovery in the native initrd.",
        categories = ["boot", "recovery"],
      },
      portability = {
        status = 'platform_specific,
        platform_leaves = [{ namespace = "host", targets = ["onixos"], rationale = "NixOS uses inventory/tags/common/initrd-ssh.nix" }],
      },
      packages = ["openssh"],
      host_packages = ["dropbear-static"],
      roles.host = {
        port | onix.Port | default = 2222,
        interface | onix.NonEmptyString,
        driver_module | onix.NonEmptyString,
        authorized_keys
          | Array onix.NonEmptyString
          | std.contract.from_predicate (fun keys => std.array.length keys > 0),
      },
    },
    impl = fun args =>
      let cfg = args.settings in
      {
        output =
          {
            host = {
              initrd_ssh = {
                package = args.package_paths."dropbear-static",
                port = cfg.port,
                interface = cfg.interface,
                driver_module = cfg.driver_module,
                authorized_keys = cfg.authorized_keys,
                host_key = "initrd-ssh/id_ed25519",
              },
              kernel.initrd_modules = [cfg.driver_module, "af_packet"],
            },
          }
          & onix.artifact_declaration {
            name = "initrd-ssh",
            files = {
              id_ed25519 = onix.artifact_file {},
              "id_ed25519.pub" = onix.artifact_file { secret = false },
            },
            generator_script = m%"
            ssh-keygen -t ed25519 -N "" -C "" -f "$out/id_ed25519"
          "%,
            description = "Initrd SSH host identity; private key is decrypted only for root-private boot installation",
          },
      },
  }
  ) | onix.ServiceModule
