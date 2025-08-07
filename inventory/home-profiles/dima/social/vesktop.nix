{ pkgs, ... }:
let
  vesktopWrapped = pkgs.vesktop.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
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
