{
  pkgs,
  ...
}:
{
  # ssh-clipboard: native clipboard sync over peer-to-peer SSH. Nix provides
  # the binary; the per-user background service, peer mesh, and the
  # ~/.local/bin/ssh-clipboard bridge path are all self-managed by the tool —
  # its updater rewrites that binary in place, so home-manager must not claim
  # it: a contested path churns backups and aborts every HM switch.
  home.packages = [
    (pkgs.callPackage ../../../../pkgs/ssh-clipboard { })
  ];
}
