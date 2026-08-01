# r[impl onix.radicle_replica.desktop_isolation]
# Keep interactive Radicle state and listeners separate from system seed nodes.
{
  pkgs,
  lib,
}:
{
  desktopHome,
  desktopSocket,
  nodeListenAddress,
  desktopPackage ? pkgs.radicle-desktop,
  nodePackage ? pkgs.radicle-node,
}:
let
  usageErrorExitCode = 64;
  managedListenDiagnostic = "radicle-node: --listen is managed by Onix on this host";
  nodeExecutable = lib.getExe' nodePackage "radicle-node";
  nodeWrapper = pkgs.writeShellApplication {
    name = "radicle-node";
    text = ''
      for argument in "$@"; do
        case "$argument" in
          --listen|--listen=*)
            printf '%s\n' ${lib.escapeShellArg managedListenDiagnostic} >&2
            exit ${toString usageErrorExitCode}
            ;;
        esac
      done

      export RAD_HOME=${lib.escapeShellArg desktopHome}
      export RAD_SOCKET=${lib.escapeShellArg desktopSocket}
      exec ${lib.escapeShellArg nodeExecutable} \
        --listen ${lib.escapeShellArg nodeListenAddress} \
        "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "radicle-desktop-onix-${desktopPackage.version or "unversioned"}";
  paths = [
    desktopPackage
    nodeWrapper
  ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram "$out/bin/radicle-desktop" \
      --set RAD_HOME ${lib.escapeShellArg desktopHome} \
      --set RAD_SOCKET ${lib.escapeShellArg desktopSocket}
  '';
  passthru = {
    onixRadicleDesktop = true;
    inherit
      desktopHome
      desktopSocket
      managedListenDiagnostic
      nodeListenAddress
      nodeWrapper
      ;
  };
  meta = desktopPackage.meta // {
    mainProgram = "radicle-desktop";
  };
}
