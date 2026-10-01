{
  inputs,
  lib,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  basePackage = inputs.niri.packages.${system}.niri;
  compatibleLibdisplayInfo = pkgs.libdisplay-info_0_3;

  isLibdisplayInfo = dependency: (dependency.pname or "") == "libdisplay-info";
  replaceLibdisplayInfo =
    dependency: if isLibdisplayInfo dependency then compatibleLibdisplayInfo else dependency;

  compatiblePackage = basePackage.overrideAttrs (
    previous:
    let
      previousBuildInputs = previous.buildInputs or [ ];
      matchingBuildInputs = lib.filter isLibdisplayInfo previousBuildInputs;
    in
    assert lib.assertMsg (
      builtins.length matchingBuildInputs == 1
    ) "the Niri package must have exactly one libdisplay-info build input";
    {
      # Niri's Rust dependency requires libdisplay-info >= 0.1.0 and < 0.4.0.
      buildInputs = map replaceLibdisplayInfo previousBuildInputs;
    }
  );
in
# Keep the script correction separate from the compositor build.
pkgs.symlinkJoin {
  name = "${compatiblePackage.name}-console-session";
  inherit (compatiblePackage) meta;
  paths = [ compatiblePackage ];
  postBuild = ''
    rm "$out/bin/niri-session"
    substitute ${compatiblePackage}/bin/niri-session "$out/bin/niri-session" \
      --replace-fail \
        " XDG_SESSION_TYPE NIRI_SOCKET'" \
        " XDG_SESSION_TYPE XDG_SESSION_ID XDG_SEAT XDG_VTNR NIRI_SOCKET'" \
      --replace-fail \
        '    systemctl --user import-environment $login_manager_variables' \
        '    export XDG_SESSION_TYPE=wayland
    systemctl --user import-environment $login_manager_variables' \
      --replace-fail \
        'systemctl --user unset-environment WAYLAND_DISPLAY' \
        'systemctl --user unset-environment XDG_SESSION_ID XDG_SEAT XDG_VTNR WAYLAND_DISPLAY'
    chmod +x "$out/bin/niri-session"
    ${pkgs.bash}/bin/bash ${./niri-session-test.sh} "$out/bin/niri-session"
  '';
}
