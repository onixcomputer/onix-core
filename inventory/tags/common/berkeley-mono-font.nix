# Berkeley Mono font — commercial font, age-encrypted at rest.
#
# The tarball at assets/fonts/berkeley-mono.tar.gz.enc is encrypted to
# all machine + admin age keys. At activation a oneshot service decrypts
# it using the machine's age key (/var/lib/sops-nix/key.txt) and
# extracts the TTF files into /var/lib/fonts/berkeley-mono/.
#
# A fontconfig snippet tells the font subsystem to search that directory,
# so the fonts become available to all users immediately after first boot.
{ pkgs, ... }:
let
  encryptedFont = ../../../assets/fonts/berkeley-mono.tar.gz.enc;
  fontDir = "/var/lib/fonts/berkeley-mono";
  ageKeyFile = "/var/lib/sops-nix/key.txt";
in
{
  # Fontconfig: make /var/lib/fonts visible to all applications
  fonts.fontconfig.localConf = ''
    <fontconfig>
      <dir>${fontDir}</dir>
    </fontconfig>
  '';

  # Decrypt and extract on every activation (idempotent)
  systemd.services.berkeley-mono-font-install = {
    description = "Decrypt and install Berkeley Mono font";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    unitConfig.ConditionPathExists = ageKeyFile;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      mkdir -p ${fontDir}
      ${pkgs.age}/bin/age --decrypt -i ${ageKeyFile} \
        ${encryptedFont} \
        | ${pkgs.gnutar}/bin/tar xzf - -C ${fontDir}
      chmod 644 ${fontDir}/*.ttf
      # Rebuild font cache so new logins pick up the fonts immediately
      ${pkgs.fontconfig}/bin/fc-cache -f ${fontDir}
    '';
  };
}
