# Berkeley Mono font — commercial font, stored as a shared clan var.
#
# On first setup run:
#   1. Create tarball:  tar czf /tmp/berkeley-mono-fonts.tar.gz -C <font-dir> *.ttf
#   2. Generate var:    clan vars generate <any-machine> -g berkeley-mono-font
#   3. Enter path:      /tmp/berkeley-mono-fonts.tar.gz
#
# The tarball is SOPS-encrypted into vars/shared/ and decrypted at
# activation time. Adding a new machine to the nixos tag automatically
# picks up the shared var — no manual re-encryption needed.
{ config, pkgs, ... }:
let
  fontDir = "/var/lib/fonts/berkeley-mono";
  fontData = config.clan.core.vars.generators.berkeley-mono-font.files.font_data.path;
in
{
  # Shared var: SOPS-encrypted font tarball available to all nixos machines
  clan.core.vars.generators.berkeley-mono-font = {
    share = true;
    files.font_data = {
      mode = "0444";
    };
    runtimeInputs = [ pkgs.coreutils ];
    prompts.font_tarball_path = {
      description = "Absolute path to Berkeley Mono font tarball (.tar.gz)";
      type = "line";
    };
    script = ''
      TARBALL=$(cat "$prompts"/font_tarball_path)
      if [ ! -f "$TARBALL" ]; then
        echo "Error: Font tarball not found: $TARBALL" >&2
        exit 1
      fi
      cp "$TARBALL" "$out"/font_data
    '';
  };

  # Fontconfig: tell the font subsystem where to find the decrypted fonts
  fonts.fontconfig.localConf = ''
    <fontconfig>
      <dir>${fontDir}</dir>
    </fontconfig>
  '';

  # Extract the decrypted tarball into the font directory on every boot
  systemd.services.berkeley-mono-font-install = {
    description = "Install Berkeley Mono font from decrypted var";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    after = [ "sops-install-secrets.service" ];
    unitConfig.ConditionPathExists = fontData;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      mkdir -p ${fontDir}
      ${pkgs.gnutar}/bin/tar xzf ${fontData} -C ${fontDir}
      chmod 644 ${fontDir}/*.ttf
      ${pkgs.fontconfig}/bin/fc-cache -f ${fontDir}
    '';
  };
}
