{
  pkgs,
  ...
}:
{
  # ssh-clipboard: native clipboard sync over peer-to-peer SSH. Nix provides
  # the binary; the per-user background service and peer mesh are created by
  # `ssh-clipboard setup` on each machine (config is self-managed in
  # ~/.config/ssh-clipboard/config.json, so it is not pinned declaratively).
  home.packages = [
    (pkgs.callPackage ../../../../pkgs/ssh-clipboard { })
  ];
}
