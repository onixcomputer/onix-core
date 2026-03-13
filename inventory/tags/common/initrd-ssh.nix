# Initrd SSH for remote debugging and disk unlock.
#
# Generates ed25519 host keys via clan vars (same pattern as iroh-ssh)
# and enables SSH on port 2222 in the initrd. Authorized keys are
# inherited from the machine's root user config.
#
# Requires boot.initrd.systemd.enable (set by srvos) and network
# in the initrd (enabled here).
#
# Adapted from clan-infra's modules/initrd-networking.nix.
{
  config,
  pkgs,
  ...
}:
{
  clan.core.vars.generators.initrd-ssh = {
    files."id_ed25519".neededFor = "activation";
    files."id_ed25519.pub".secret = false;
    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssh
    ];
    script = ''
      ssh-keygen -t ed25519 -N "" -f $out/id_ed25519
    '';
  };

  boot = {
    initrd = {
      systemd.enable = true;

      network = {
        enable = true;
        ssh = {
          enable = true;
          port = 2222;
          hostKeys = [
            config.clan.core.vars.generators.initrd-ssh.files.id_ed25519.path
          ];
          authorizedKeys = config.users.users.root.openssh.authorizedKeys.keys;
        };
      };

      # For debugging installation in VMs
      kernelModules = [
        "virtio_pci"
        "virtio_net"
      ];
    };
  };
}
