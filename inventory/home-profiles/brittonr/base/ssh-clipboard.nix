{
  pkgs,
  lib,
  ...
}:
let
  sshClipboard = pkgs.callPackage ../../../../pkgs/ssh-clipboard { };
in
{
  # ssh-clipboard: native clipboard sync over peer-to-peer SSH. Nix provides
  # the binary; the per-user background service and peer mesh are created by
  # `ssh-clipboard setup` on each machine (config is self-managed in
  # ~/.config/ssh-clipboard/config.json, so it is not pinned declaratively).
  home.packages = [ sshClipboard ];

  # Incoming peer bridges exec "$HOME/.local/bin/ssh-clipboard" on this
  # machine (upstream's hardcoded bridge path), so expose the Nix-built
  # binary there too.
  home.file.".local/bin/ssh-clipboard".source = lib.getExe sshClipboard;
}
