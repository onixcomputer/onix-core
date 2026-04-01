# Install Mic92/noctalia-plugins into ~/.config/noctalia/plugins/
# Same pattern as the wl-walls plugin in niri.nix — copy QML + manifest
# into the mutable plugins dir so Noctalia discovers them at runtime.
# Enable/disable individual plugins via Settings → Plugins.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  pluginsSrc = inputs.noctalia-plugins;

  # All plugins from the repo
  pluginNames = [
    "alertmanager"
    "desktop-calendar"
    "display-config"
    "fprint-notify"
    "khal-next"
    "mail-count"
    "nostr-chat"
    "rbw-provider"
    "ssh-askpass"
  ];

  sshAskpassPkg =
    inputs.noctalia-plugins.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-ssh-askpass;
  nostrChatdPkg = inputs.noctalia-plugins.packages.${pkgs.stdenv.hostPlatform.system}.nostr-chatd;
in
{
  # Companion binaries for plugins that need them
  home.packages = [
    sshAskpassPkg
    nostrChatdPkg
  ];

  home.activation = {
    # Install all noctalia-plugins QML files, manifests, and i18n
    installNoctaliaPlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      plugin_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins"
      ${lib.concatMapStringsSep "\n" (name: ''
        # ── ${name} ──
        mkdir -p "$plugin_dir/${name}"
        for f in ${pluginsSrc}/${name}/*.qml ${pluginsSrc}/${name}/*.js ${pluginsSrc}/${name}/*.json; do
          [ -f "$f" ] && install -m 644 "$f" "$plugin_dir/${name}/"
        done
        if [ -d "${pluginsSrc}/${name}/i18n" ]; then
          mkdir -p "$plugin_dir/${name}/i18n"
          for f in ${pluginsSrc}/${name}/i18n/*.json; do
            [ -f "$f" ] && install -m 644 "$f" "$plugin_dir/${name}/i18n/"
          done
        fi
      '') pluginNames}
    '';
  };
}
