{ pkgs, ... }:
let
  vesktopWrapped = pkgs.vesktop.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postPatch = (oldAttrs.postPatch or "") + ''
      # Fix EACCES permission denied when @electron/fuses tries to modify electron binary
      # Remove electronFuses from package.json since we can't write to the binary
      # copied from the read-only Nix store
      ${pkgs.jq}/bin/jq 'del(.build.electronFuses)' package.json > package.json.tmp
      mv package.json.tmp package.json
    '';
    postFixup = (oldAttrs.postFixup or "") + ''
      wrapProgram $out/bin/vesktop \
        --add-flags "--enable-features=WaylandWindowDecorations" \
        --add-flags "--ozone-platform-hint=wayland"
    '';
  });
in
{
  programs.vesktop = {
    enable = true;
    package = vesktopWrapped;
  };
}
